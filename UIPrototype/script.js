const tabButtons = document.querySelectorAll(".tab-bar button");
const screens = document.querySelectorAll(".screen");

tabButtons.forEach((button) => {
  button.addEventListener("click", () => {
    const target = button.dataset.target;

    tabButtons.forEach((item) => item.classList.remove("active"));
    screens.forEach((screen) => {
      screen.classList.toggle("active", screen.dataset.screen === target);
    });

    button.classList.add("active");
  });
});
