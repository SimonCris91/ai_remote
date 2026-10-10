const statusPill = document.querySelector("#service-status");
const statusText = document.querySelector("#service-status-text");
const noticeStatus = document.querySelector("#notice-status");
document.querySelector("#year").textContent = new Date().getFullYear();

async function refreshServiceStatus() {
  try {
    const response = await fetch("/health", {
      cache: "no-store",
      signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) throw new Error("Health check failed");
    const health = await response.json();
    if (health.status !== "ok") throw new Error("Service unavailable");
    statusPill.dataset.state = "online";
    statusText.textContent = "Backend online";
    noticeStatus.dataset.state = "online";
    noticeStatus.textContent = "Servizio raggiungibile";
  } catch {
    statusPill.dataset.state = "offline";
    statusText.textContent = "Backend non raggiungibile";
    noticeStatus.dataset.state = "offline";
    noticeStatus.textContent = "Servizio non raggiungibile";
  }
}

refreshServiceStatus();
window.setInterval(refreshServiceStatus, 60_000);
