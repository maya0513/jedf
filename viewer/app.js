import { render_document, render_container } from "./jedf-web.js";

const view = document.getElementById("view");

function showText(text) {
  view.innerHTML = render_document(text);
}

function showContainer(buffer) {
  view.innerHTML = render_container(new Uint8Array(buffer));
}

async function openExample(name) {
  const response = await fetch(`./${name}.jedf`);
  showText(await response.text());
}

async function openContainer(name) {
  const response = await fetch(`./${name}.jedfc`);
  showContainer(await response.arrayBuffer());
}

for (const button of document.querySelectorAll("[data-example]")) {
  button.addEventListener("click", () => openExample(button.dataset.example));
}

for (const button of document.querySelectorAll("[data-container]")) {
  button.addEventListener("click", () => openContainer(button.dataset.container));
}

document.getElementById("file").addEventListener("change", async (event) => {
  const file = event.target.files[0];
  if (!file) {
    return;
  }
  if (file.name.endsWith(".jedfc")) {
    showContainer(await file.arrayBuffer());
  } else {
    showText(await file.text());
  }
});

openExample("showcase");
