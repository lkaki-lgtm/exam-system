// public/js/proctor.js - Fixed Proctoring System

let model;
let video;
let violationCount = 0;
let proctorAttemptId = null;
let faceDetectionInterval = null;
let tabSwitchCount = 0;
let blurCount = 0;
let copyPasteCount = 0;
let devToolsDetected = false;
let examTerminated = false;

function showProctorStatus(message, color = "green") {
  const statusEl = document.getElementById("proctor-status");
  if (!statusEl) return;

  statusEl.textContent = message;
  statusEl.classList.remove("hidden", "bg-green-500", "bg-yellow-500", "bg-red-500");

  if (color === "green") statusEl.classList.add("bg-green-500");
  else if (color === "yellow") statusEl.classList.add("bg-yellow-500");
  else statusEl.classList.add("bg-red-500");
}

function showWarning(message) {
  const warningEl = document.getElementById("proctor-warning");
  if (!warningEl) return;

  warningEl.textContent = `⚠️ ${message}`;
  warningEl.classList.remove("hidden");

  setTimeout(() => {
    warningEl.classList.add("hidden");
  }, 3000);
}

function hideWarning() {
  const warningEl = document.getElementById("proctor-warning");
  if (warningEl) warningEl.classList.add("hidden");
}

async function initProctor(attemptIdValue) {
  proctorAttemptId = attemptIdValue;

  try {
    initSecurityFeatures();

    if (typeof blazeface !== "undefined") {
      model = await blazeface.load();
      console.log("✅ Face detection model loaded");
      await setupWebcam();
      startFaceDetection();
      showProctorStatus("🛡️ Proctoring active", "green");
    } else {
      console.warn("⚠️ BlazeFace not available");
      showProctorStatus("⚠️ Camera AI unavailable", "yellow");
    }
  } catch (error) {
    console.error("❌ Proctoring initialization failed:", error);
    showProctorStatus("⚠️ Limited security mode", "yellow");
  }
}

function initSecurityFeatures() {
  document.addEventListener("visibilitychange", handleVisibilityChange);
  document.addEventListener("copy", handleCopy);
  document.addEventListener("cut", handleCut);
  document.addEventListener("paste", handlePaste);
  document.addEventListener("contextmenu", handleRightClick);
  window.addEventListener("blur", handleWindowBlur);
  document.addEventListener("keydown", handleKeyDown);

  setInterval(detectDevTools, 1000);
  console.log("✅ Security features initialized");
}

async function setupWebcam() {
  video = document.createElement("video");
  video.width = 320;
  video.height = 240;
  video.autoplay = true;
  video.playsInline = true;
  video.muted = true;

  video.style.position = "fixed";
  video.style.bottom = "10px";
  video.style.right = "10px";
  video.style.width = "160px";
  video.style.height = "120px";
  video.style.borderRadius = "8px";
  video.style.border = "2px solid #10b981";
  video.style.zIndex = "1000";
  video.style.background = "#000";
  video.style.display = "block";

  document.body.appendChild(video);

  const stream = await navigator.mediaDevices.getUserMedia({
    video: {
      width: 320,
      height: 240,
      facingMode: "user"
    },
    audio: false
  });

  video.srcObject = stream;

  return new Promise((resolve) => {
    video.onloadedmetadata = async () => {
      try {
        await video.play();
        console.log("✅ Webcam started");
        resolve();
      } catch (e) {
        console.error("Video play failed:", e);
        resolve();
      }
    };
  });
}

function startFaceDetection() {
  if (!model || !video) return;

  faceDetectionInterval = setInterval(async () => {
    try {
      const predictions = await model.estimateFaces(video, false);

      if (predictions.length === 0) {
        handleViolation("no_face", "No face detected", 2);
      } else if (predictions.length > 1) {
        handleViolation("multiple_faces", "Multiple faces detected", 5);
      } else {
        hideWarning();
      }
    } catch (error) {
      console.error("Face detection error:", error);
    }
  }, 2000);
}

function handleVisibilityChange() {
  if (document.hidden) {
    tabSwitchCount++;
    handleViolation("tab_switch", `Tab switch #${tabSwitchCount}`, 3);
    logViolationToServer("tab_switch", { count: tabSwitchCount });
  }
}

function handleCopy(e) {
  e.preventDefault();
  copyPasteCount++;
  handleViolation("copy_attempt", "Copying is not allowed", 2);
  logViolationToServer("copy_attempt", { count: copyPasteCount });
  return false;
}

function handleCut(e) {
  e.preventDefault();
  copyPasteCount++;
  handleViolation("cut_attempt", "Cutting is not allowed", 2);
  logViolationToServer("cut_attempt", { count: copyPasteCount });
  return false;
}

function handlePaste(e) {
  e.preventDefault();
  copyPasteCount++;
  handleViolation("paste_attempt", "Pasting is not allowed", 2);
  logViolationToServer("paste_attempt", { count: copyPasteCount });
  return false;
}

function handleRightClick(e) {
  e.preventDefault();
  handleViolation("right_click", "Right-click is disabled", 1);
  logViolationToServer("right_click", {});
  return false;
}

function handleWindowBlur() {
  blurCount++;
  handleViolation("window_blur", "Exam window left", 3);
  logViolationToServer("window_blur", { count: blurCount });
}

function handleKeyDown(e) {
  if (e.ctrlKey || e.metaKey) {
    if (["c", "v", "x", "s", "p"].includes(e.key.toLowerCase())) {
      e.preventDefault();
      handleViolation("keyboard_shortcut", `Ctrl+${e.key} is disabled`, 2);
      logViolationToServer("keyboard_shortcut", { key: e.key });
      return false;
    }
  }

  if (
    e.key === "F12" ||
    (e.ctrlKey && e.shiftKey && ["I", "J", "C"].includes(e.key))
  ) {
    e.preventDefault();
    handleViolation("dev_tools", "Developer tools are disabled", 5);
    logViolationToServer("dev_tools", {});
    return false;
  }
}

function detectDevTools() {
  const widthThreshold = window.outerWidth - window.innerWidth > 160;
  const heightThreshold = window.outerHeight - window.innerHeight > 160;

  if ((widthThreshold || heightThreshold) && !devToolsDetected) {
    devToolsDetected = true;
    handleViolation("dev_tools_detected", "Developer tools detected", 5);
    logViolationToServer("dev_tools_detected", {});
  } else if (!(widthThreshold || heightThreshold)) {
    devToolsDetected = false;
  }
}

function handleViolation(type, message, severity = 1) {
  if (examTerminated) return;

  violationCount += severity;
  console.log(`⚠️ Violation: ${type}`, message, "Total:", violationCount);

  showWarning(message);

  if (violationCount >= 10) {
    showWarning("FINAL WARNING: Too many violations");
  }

  if (violationCount >= 15) {
    terminateExam("Multiple security violations");
  }
}

async function logViolationToServer(type, details = {}) {
  if (!proctorAttemptId) return;

  try {
    await fetch("/student/exam/report-violation", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        attempt_id: proctorAttemptId,
        type: type,
        message: details.message || type,
        details: details,
        total_violations: violationCount,
        timestamp: new Date().toISOString()
      })
    });
  } catch (error) {
    console.error("Failed to log violation:", error);
  }
}

function stopProctor() {
  if (faceDetectionInterval) {
    clearInterval(faceDetectionInterval);
    faceDetectionInterval = null;
  }

  if (video && video.srcObject) {
    video.srcObject.getTracks().forEach(track => track.stop());
    video.remove();
    video = null;
  }
}

function terminateExam(reason) {
  if (examTerminated) return;
  examTerminated = true;

  stopProctor();

  document.querySelectorAll("input, button, textarea, select").forEach(el => {
    el.disabled = true;
  });

  fetch("/student/exam/terminate", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      attempt_id: proctorAttemptId,
      reason: reason
    })
  })
  .then(res => res.json())
  .then(data => {
    alert("Exam terminated: " + reason);
    window.location.href = data.redirect || "/student/dashboard";
  })
  .catch(err => {
    console.error("Terminate failed:", err);
    window.location.href = "/student/dashboard";
  });
}

window.initProctor = initProctor;
window.stopProctor = stopProctor;
window.terminateExam = terminateExam;