import { invoke, listen, currentWindow, thumbnailUrl } from "./shared.js";

const img = document.getElementById("thumb");
let currentPath = null;

img.addEventListener("click", async () => {
  if (!currentPath) return;
  await invoke("open_screenshot", { path: currentPath });
  currentWindow().hide();
});

listen("toast-show", async (event) => {
  currentPath = event.payload.path;
  const url = await thumbnailUrl(event.payload.path, 300);
  if (url) img.src = url;
});
