import { render_document } from "./jedf-web.js";

const view = document.getElementById("view");

function show(text) {
  view.innerHTML = render_document(text);
}

async function openExample(name) {
  const response = await fetch(`./${name}.jedf`);
  show(await response.text());
}

for (const button of document.querySelectorAll("[data-example]")) {
  button.addEventListener("click", () => openExample(button.dataset.example));
}

document.getElementById("file").addEventListener("change", async (event) => {
  const file = event.target.files[0];
  if (file) {
    show(await file.text());
  }
});

openExample("showcase");
