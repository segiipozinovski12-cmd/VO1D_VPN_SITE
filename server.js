import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const port = Number(process.env.PORT || 3000);
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const files = {
  "/": ["index.html", "text/html; charset=utf-8"],
  "/index.html": ["index.html", "text/html; charset=utf-8"],
  "/style.css": ["style.css", "text/css; charset=utf-8"],
  "/app.js": ["app.js", "text/javascript; charset=utf-8"],
};

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "content-type": "application/json", "cache-control": "no-store" });
    return res.end(JSON.stringify({ ok: true, service: "VO1D_VPN", version: "2.0" }));
  }

  const pathname = (req.url || "/").split("?")[0];
  const entry = files[pathname] || files["/"];
  const filePath = path.join(__dirname, entry[0]);
  try {
    const data = fs.readFileSync(filePath);
    res.writeHead(200, {
      "content-type": entry[1],
      "cache-control": pathname === "/" ? "no-cache" : "public, max-age=300",
      "x-content-type-options": "nosniff",
      "referrer-policy": "strict-origin-when-cross-origin",
      "x-frame-options": "SAMEORIGIN",
    });
    res.end(data);
  } catch {
    res.writeHead(500, { "content-type": "text/plain; charset=utf-8" });
    res.end("VO1D_VPN asset error");
  }
});

server.listen(port, "0.0.0.0", () => console.log("VO1D_VPN online on " + port));