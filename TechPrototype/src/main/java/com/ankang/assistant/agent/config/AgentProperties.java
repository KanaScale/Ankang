package com.ankang.assistant.agent.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "agent")
public class AgentProperties {
    private String provider = "openai";
    private String baseUrl = "https://models.sjtu.edu.cn/api/v1";
    private String apiKey;
    private String modelName = "deepseek-chat";
    private Qdrant qdrant = new Qdrant();
    private WebSearch webSearch = new WebSearch();
    private Gms gms = new Gms();

    public String getProvider() {
        return provider;
    }

    public void setProvider(String provider) {
        this.provider = provider;
    }

    public String getBaseUrl() {
        return baseUrl;
    }

    public void setBaseUrl(String baseUrl) {
        this.baseUrl = baseUrl;
    }

    public String getApiKey() {
        return apiKey;
    }

    public void setApiKey(String apiKey) {
        this.apiKey = apiKey;
    }

    public String getModelName() {
        return modelName;
    }

    public void setModelName(String modelName) {
        this.modelName = modelName;
    }

    public Qdrant getQdrant() {
        return qdrant;
    }

    public void setQdrant(Qdrant qdrant) {
        this.qdrant = qdrant;
    }

    public WebSearch getWebSearch() {
        return webSearch;
    }

    public void setWebSearch(WebSearch webSearch) {
        this.webSearch = webSearch;
    }

    public Gms getGms() {
        if (gms == null) {
            gms = new Gms();
        }
        return gms;
    }

    public void setGms(Gms gms) {
        this.gms = gms == null ? new Gms() : gms;
    }

    public boolean llmEnabled() {
        return !"mock".equalsIgnoreCase(provider) && apiKey != null && !apiKey.isBlank();
    }

    public static class Qdrant {
        private String host = "127.0.0.1";
        private Integer port = 6333;
        private String collection = "ankang_knowledge";

        public String getHost() {
            return host;
        }

        public void setHost(String host) {
            this.host = host;
        }

        public Integer getPort() {
            return port;
        }

        public void setPort(Integer port) {
            this.port = port;
        }

        public String getCollection() {
            return collection;
        }

        public void setCollection(String collection) {
            this.collection = collection;
        }
    }

    public static class WebSearch {
        private boolean enabled = true;
        private String provider = "mock";
        private String apiKey;
        private String baseUrl;
        private Integer maxResults = 5;
        private Integer timeoutSeconds = 8;

        public boolean isEnabled() {
            return enabled;
        }

        public void setEnabled(boolean enabled) {
            this.enabled = enabled;
        }

        public String getProvider() {
            return provider;
        }

        public void setProvider(String provider) {
            this.provider = provider;
        }

        public String getApiKey() {
            return apiKey;
        }

        public void setApiKey(String apiKey) {
            this.apiKey = apiKey;
        }

        public String getBaseUrl() {
            return baseUrl;
        }

        public void setBaseUrl(String baseUrl) {
            this.baseUrl = baseUrl;
        }

        public Integer getMaxResults() {
            return maxResults == null || maxResults <= 0 ? 5 : maxResults;
        }

        public void setMaxResults(Integer maxResults) {
            this.maxResults = maxResults;
        }

        public Integer getTimeoutSeconds() {
            return timeoutSeconds == null || timeoutSeconds <= 0 ? 8 : timeoutSeconds;
        }

        public void setTimeoutSeconds(Integer timeoutSeconds) {
            this.timeoutSeconds = timeoutSeconds;
        }

        public boolean realProviderEnabled() {
            return enabled
                    && provider != null
                    && !"mock".equalsIgnoreCase(provider)
                    && apiKey != null
                    && !apiKey.isBlank();
        }
    }

    public static class Gms {
        private boolean enabled = false;
        private boolean writeEnabled = true;
        private String baseUrl = "http://127.0.0.1:8091";
        private Integer timeoutMillis = 800;
        private Integer readLimit = 5;

        public boolean isEnabled() {
            return enabled;
        }

        public void setEnabled(boolean enabled) {
            this.enabled = enabled;
        }

        public boolean isWriteEnabled() {
            return writeEnabled;
        }

        public void setWriteEnabled(boolean writeEnabled) {
            this.writeEnabled = writeEnabled;
        }

        public String getBaseUrl() {
            return baseUrl == null || baseUrl.isBlank() ? "http://127.0.0.1:8091" : baseUrl;
        }

        public void setBaseUrl(String baseUrl) {
            this.baseUrl = baseUrl;
        }

        public Integer getTimeoutMillis() {
            return timeoutMillis == null || timeoutMillis <= 0 ? 800 : timeoutMillis;
        }

        public void setTimeoutMillis(Integer timeoutMillis) {
            this.timeoutMillis = timeoutMillis;
        }

        public Integer getReadLimit() {
            return readLimit == null || readLimit <= 0 ? 5 : readLimit;
        }

        public void setReadLimit(Integer readLimit) {
            this.readLimit = readLimit;
        }
    }
}
