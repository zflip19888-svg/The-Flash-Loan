const fs = require("fs");

const REPO = "zflip19888-svg/The-Flash-Loan";
const TOKEN = process.env.GITHUB_TOKEN_2;
const BRANCH = "main";
const PATH = "logs/opportunities-2026-09-16.jsonl";
const LOCAL = "logs/opportunities-2026-09-16.jsonl";

const API = `https://api.github.com/repos/${REPO}`;

async function gh(path, opts = {}) {
  const res = await fetch(`${API}/${path}`, {
    ...opts,
    headers: {
      "Authorization": `Bearer ${TOKEN}`,
      "Accept": "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "Content-Type": "application/json",
      ...opts.headers,
    },
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`GitHub ${res.status}: ${JSON.stringify(data)}`);
  return data;
}

(async () => {
  let sha = null;
  try {
    const existing = await gh(`contents/${PATH}?ref=${BRANCH}`);
    sha = existing.sha;
    console.log(`File exists, updating SHA ${sha}`);
  } catch { console.log("New file."); }

  const content = fs.readFileSync(LOCAL).toString("base64");
  const msg = `Daily scan log: 2026-09-16 (block #93886504, MATIC $0.0918, 5 pairs scanned)`;
  const result = await gh(`contents/${PATH}`, {
    method: "PUT",
    body: JSON.stringify({ message: msg, content, branch: BRANCH, ...(sha ? { sha } : {}) }),
  });
  console.log("Committed:", result.commit.html_url);
})();
