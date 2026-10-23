#!/usr/bin/env python3
"""Qdrant RAG memory scale and tenant-isolation smoke test.

The test writes public health points and private per-user points, then verifies
that the query filter returns public data plus only the current user's private
data. It intentionally uses deterministic synthetic vectors so the test does
not spend embedding API quota.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import statistics
import sys
import time
import uuid
from dataclasses import dataclass
from typing import Any
from urllib import error, request


DEFAULT_COLLECTION = "ankang_rag_scale_test_4096"


@dataclass
class QdrantClient:
    base_url: str
    timeout: int

    def call(self, method: str, path: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
        data = json.dumps(payload).encode("utf-8") if payload is not None else None
        req = request.Request(
            self.base_url.rstrip("/") + path,
            data=data,
            method=method,
            headers={"Content-Type": "application/json"},
        )
        try:
            with request.urlopen(req, timeout=self.timeout) as resp:
                body = resp.read().decode("utf-8")
                return json.loads(body) if body else {}
        except error.HTTPError as exc:
            body = exc.read().decode("utf-8", "replace")
            raise RuntimeError(f"Qdrant {method} {path} failed: HTTP {exc.code} {body}") from exc


def vector_for(namespace: str, key: int, dimensions: int) -> list[float]:
    salt = 17 if namespace == "public" else 97
    scale = key + salt
    values = [
        math.sin((scale * (i + 1)) % 997 / 37.0) + math.cos((scale + i * 13) % 991 / 41.0)
        for i in range(dimensions)
    ]
    norm = math.sqrt(sum(v * v for v in values)) or 1.0
    return [round(v / norm, 8) for v in values]


def batched(items: list[dict[str, Any]], batch_size: int):
    for start in range(0, len(items), batch_size):
        yield items[start : start + batch_size]


def ensure_collection(client: QdrantClient, collection: str, dimensions: int, recreate: bool) -> None:
    exists = True
    try:
        state = client.call("GET", f"/collections/{collection}")
    except RuntimeError:
        exists = False
        state = {}

    if exists and recreate:
        client.call("DELETE", f"/collections/{collection}")
        exists = False

    if not exists:
        client.call(
            "PUT",
            f"/collections/{collection}",
            {"vectors": {"size": dimensions, "distance": "Cosine"}},
        )
        return

    vector_config = (
        state.get("result", {})
        .get("config", {})
        .get("params", {})
        .get("vectors", {})
    )
    actual_size = vector_config.get("size")
    if actual_size != dimensions:
        raise RuntimeError(
            f"Collection {collection} vector size is {actual_size}, expected {dimensions}. "
            "Use a temporary collection or recreate it with the expected embedding size."
        )


def ensure_indexes(client: QdrantClient, collection: str) -> None:
    indexes = {
        "visibility": "keyword",
        "userId": "integer",
        "sourceType": "keyword",
        "category": "keyword",
        "documentId": "integer",
        "testRunId": "keyword",
    }
    for field_name, field_schema in indexes.items():
        try:
            client.call(
                "PUT",
                f"/collections/{collection}/index",
                {"field_name": field_name, "field_schema": field_schema},
            )
        except RuntimeError as exc:
            # Qdrant may reject duplicate index creation on some versions.
            if "already exists" not in str(exc) and "Wrong input" not in str(exc):
                raise


def build_points(
    users: int,
    private_per_user: int,
    public_points: int,
    dimensions: int,
    run_id: str,
) -> list[dict[str, Any]]:
    points: list[dict[str, Any]] = []
    for idx in range(1, public_points + 1):
        points.append(
            {
                "id": idx,
                "vector": vector_for("public", idx, dimensions),
                "payload": {
                    "visibility": "public",
                    "sourceType": "scale_test",
                    "category": "public_health_knowledge",
                    "documentId": idx,
                    "testRunId": run_id,
                    "text": f"公共健康知识测试片段 {idx}",
                },
            }
        )

    for user_id in range(1, users + 1):
        base_vector = vector_for("private", user_id, dimensions)
        for doc_idx in range(1, private_per_user + 1):
            point_id = 1_000_000_000 + user_id * 1000 + doc_idx
            points.append(
                {
                    "id": point_id,
                    "vector": base_vector,
                    "payload": {
                        "visibility": "private",
                        "userId": user_id,
                        "sourceType": "scale_test",
                        "category": "personal_health_memory",
                        "documentId": point_id,
                        "testRunId": run_id,
                        "text": f"用户 {user_id} 的私有健康记忆测试片段 {doc_idx}",
                    },
                }
            )
    return points


def tenant_filter(user_id: int) -> dict[str, Any]:
    return {
        "should": [
            {"must": [{"key": "visibility", "match": {"value": "public"}}]},
            {
                "must": [
                    {"key": "visibility", "match": {"value": "private"}},
                    {"key": "userId", "match": {"value": user_id}},
                ]
            },
        ]
    }


def verify_reads(
    client: QdrantClient,
    collection: str,
    users: int,
    read_sample: int,
    dimensions: int,
    limit: int,
) -> dict[str, Any]:
    latencies_ms: list[float] = []
    isolation_errors: list[dict[str, Any]] = []
    missing_private_hits: list[int] = []
    sampled_users = list(range(1, min(users, read_sample) + 1))

    for user_id in sampled_users:
        started = time.perf_counter()
        result = client.call(
            "POST",
            f"/collections/{collection}/points/search",
            {
                "vector": vector_for("private", user_id, dimensions),
                "limit": limit,
                "with_payload": True,
                "filter": tenant_filter(user_id),
            },
        )
        latencies_ms.append((time.perf_counter() - started) * 1000)
        hits = result.get("result", [])
        saw_own_private = False
        for hit in hits:
            payload = hit.get("payload", {})
            visibility = payload.get("visibility")
            hit_user_id = payload.get("userId")
            if visibility == "private" and hit_user_id == user_id:
                saw_own_private = True
            if visibility == "private" and hit_user_id != user_id:
                isolation_errors.append(
                    {
                        "queryUserId": user_id,
                        "leakedUserId": hit_user_id,
                        "pointId": hit.get("id"),
                    }
                )
        if not saw_own_private:
            missing_private_hits.append(user_id)

    negative = client.call(
        "POST",
        f"/collections/{collection}/points/search",
        {
            "vector": vector_for("private", users + 9999, dimensions),
            "limit": limit,
            "with_payload": True,
            "filter": tenant_filter(users + 9999),
        },
    )
    negative_private_hits = [
        hit
        for hit in negative.get("result", [])
        if hit.get("payload", {}).get("visibility") == "private"
    ]

    return {
        "readChecks": len(sampled_users),
        "isolationErrors": isolation_errors,
        "missingPrivateHits": missing_private_hits,
        "negativeUserPrivateHits": len(negative_private_hits),
        "latencyMs": {
            "min": round(min(latencies_ms), 2),
            "avg": round(statistics.fmean(latencies_ms), 2),
            "p95": round(statistics.quantiles(latencies_ms, n=20)[18], 2)
            if len(latencies_ms) >= 20
            else round(max(latencies_ms), 2),
            "max": round(max(latencies_ms), 2),
        },
    }


def cleanup(client: QdrantClient, collection: str, run_id: str, delete_collection: bool) -> None:
    if delete_collection:
        client.call("DELETE", f"/collections/{collection}")
        return
    client.call(
        "POST",
        f"/collections/{collection}/points/delete?wait=true",
        {"filter": {"must": [{"key": "testRunId", "match": {"value": run_id}}]}},
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Qdrant 1000-user RAG memory scale test")
    parser.add_argument("--qdrant-url", default=os.getenv("QDRANT_URL", "http://127.0.0.1:6333"))
    parser.add_argument("--collection", default=os.getenv("QDRANT_TEST_COLLECTION", DEFAULT_COLLECTION))
    parser.add_argument("--users", type=int, default=1000)
    parser.add_argument("--private-per-user", type=int, default=1)
    parser.add_argument("--public-points", type=int, default=20)
    parser.add_argument("--dimensions", type=int, default=int(os.getenv("EMBEDDING_DIMENSIONS", "4096")))
    parser.add_argument("--batch-size", type=int, default=64)
    parser.add_argument("--read-sample", type=int, default=1000)
    parser.add_argument("--search-limit", type=int, default=8)
    parser.add_argument("--timeout", type=int, default=60)
    parser.add_argument("--keep", action="store_true", help="Keep test collection/data after the run")
    parser.add_argument("--no-recreate", action="store_true", help="Do not recreate the target collection")
    parser.add_argument("--output", help="Write JSON result summary to this path")
    args = parser.parse_args()

    run_id = f"rag-scale-{int(time.time())}-{uuid.uuid4().hex[:8]}"
    client = QdrantClient(args.qdrant_url, args.timeout)
    delete_collection = args.collection == DEFAULT_COLLECTION and not args.keep
    recreate = not args.no_recreate
    started = time.perf_counter()

    summary: dict[str, Any] = {
        "runId": run_id,
        "qdrantUrl": args.qdrant_url,
        "collection": args.collection,
        "users": args.users,
        "privatePerUser": args.private_per_user,
        "publicPoints": args.public_points,
        "dimensions": args.dimensions,
    }

    try:
        print(f"[1/5] ensuring collection {args.collection}")
        ensure_collection(client, args.collection, args.dimensions, recreate)
        ensure_indexes(client, args.collection)

        print("[2/5] building deterministic test points")
        points = build_points(
            args.users,
            args.private_per_user,
            args.public_points,
            args.dimensions,
            run_id,
        )

        print(f"[3/5] upserting {len(points)} points")
        upsert_started = time.perf_counter()
        for batch in batched(points, args.batch_size):
            client.call("PUT", f"/collections/{args.collection}/points?wait=true", {"points": batch})
        summary["write"] = {
            "points": len(points),
            "seconds": round(time.perf_counter() - upsert_started, 2),
        }

        print(f"[4/5] verifying filtered reads for {min(args.users, args.read_sample)} users")
        summary["read"] = verify_reads(
            client,
            args.collection,
            args.users,
            args.read_sample,
            args.dimensions,
            args.search_limit,
        )
        summary["passed"] = (
            not summary["read"]["isolationErrors"]
            and not summary["read"]["missingPrivateHits"]
            and summary["read"]["negativeUserPrivateHits"] == 0
        )
        summary["totalSeconds"] = round(time.perf_counter() - started, 2)
    finally:
        if not args.keep:
            print("[5/5] cleaning test data")
            cleanup(client, args.collection, run_id, delete_collection)

    if args.output:
        with open(args.output, "w", encoding="utf-8") as fh:
            json.dump(summary, fh, ensure_ascii=False, indent=2)
            fh.write("\n")

    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0 if summary.get("passed") else 1


if __name__ == "__main__":
    sys.exit(main())
