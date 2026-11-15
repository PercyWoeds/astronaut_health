import "controllers"

if ("serviceWorker" in navigator &&
    (window.isSecureContext || ["localhost", "127.0.0.1"].includes(window.location.hostname))) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js")
      .catch(() => { /* offline shell unavailable; app still works online */ });
  });
}
