# DeepSeek Harness (dsh) — লোকাল সেটআপ গাইড

**তৈরি:** সেপ্টেম্বর ২০২৬
**পরিবেশ:** Windows · macOS · Linux/Ubuntu (macOS নির্দেশনা: অংশ ২; Linux Figma সীমাবদ্ধতা: অংশ ৩)
**অবস্থা:** dsh এখনো developer preview — breaking change আসতে পারে

> **পাথ নিয়ে:** ডকুমেন্টে `%USERPROFILE%` মানে আপনার ইউজার ফোল্ডার (যেমন `C:\Users\AC`)। **cmd**-এ এটা নিজে থেকেই কাজ করে, Windows-এর ফাইল ডায়ালগেও পেস্ট করলে খুলে যায়। **PowerShell**-এ ব্যবহার করলে বদলে `$env:USERPROFILE` লিখুন। **macOS/Linux-এ** বদলে `~` (হোম ফোল্ডার, যেমন `/Users/AC`) — `%USERPROFILE%\.dsh` = `~/.dsh`।

> **প্রতি মেশিনে যা হাতে করতে হবে:** Anthropic API key, Figma PAT, Figma ডেস্কটপে লগইন, ব্রিজ প্লাগইন ইমপোর্ট, workspace সিলেক্ট। বাকিটা কমান্ড চালালেই হয়ে যায়।

**সূচি**

- [dsh আসলে কী](#dsh-আসলে-কী)
- [অংশ ১ — Windows সেটআপ](#অংশ-১--windows-সেটআপ)
- [অংশ ২ — macOS সেটআপ](#অংশ-২--macos-সেটআপ)
- [অংশ ৩ — Linux (Ubuntu) সেটআপ](#অংশ-৩--linux-ubuntu-সেটআপ)
- [অংশ ৪ — যা করবেন না](#অংশ-৪--যা-করবেন-না)
- [অংশ ৫ — নিরাপদ ব্যবহারের নিয়ম](#অংশ-৫--নিরাপদ-ব্যবহারের-নিয়ম)
- [অংশ ৬ — Figma ইন্টিগ্রেশন (create / edit / read)](#অংশ-৬--figma-ইন্টিগ্রেশন-create--edit--read)
- [অংশ ৭ — প্রজেক্ট সেটআপ ও কাজের প্রবাহ](#অংশ-৭--প্রজেক্ট-সেটআপ-ও-কাজের-প্রবাহ)
- [অংশ ৮ — Troubleshooting](#অংশ-৮--troubleshooting)
- [অংশ ৯ — নতুন PC-তে সেটআপ চেকলিস্ট](#অংশ-৯--নতুন-pc-তে-সেটআপ-চেকলিস্ট)
- [দ্রুত রেফারেন্স](#দ্রুত-রেফারেন্স)

---

## dsh আসলে কী

DeepSeek Harness (`dsh`) একটা open-source agent harness — DeepSeek AI-এর বানানো, MIT লাইসেন্স। মূল ধারণা: **everything is a plugin**। মডেল, টুল, সেশন, স্যান্ডবক্স, স্টোরেজ, UI — সবই প্লাগইন, কনফিগ দিয়ে বদলানো যায়।

গুরুত্বপূর্ণ: **harness লোকাল, মডেল লোকাল নয়।** API কল যাচ্ছে DeepSeek বা Anthropic-এর সার্ভারে।

**রেফারেন্স লিংক**

- সাইট: https://www.deepseek.com/harness/en/
- GitHub: https://github.com/deepseek-ai/deepseek-harness
- ডকস: https://deepseek-harness.github.io/deepseek-harness/en/guide/quickstart

---

## অংশ ১ — Windows সেটআপ

> **টার্মিনাল নিয়ে একটা কথা:** PowerShell-এ ডিফল্টভাবে স্ক্রিপ্ট চালানো বন্ধ থাকে, ফলে `npm`/`npx` এরর দেয় (`.ps1 cannot be loaded`)। সবচেয়ে ঝামেলামুক্ত উপায় — **cmd ব্যবহার করুন** (Win+R → `cmd`)। PowerShell-ই পছন্দ হলে একবার চালিয়ে নিন: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

### ধাপ ১: Node.js

```powershell
winget install OpenJS.NodeJS.LTS
```

**ইনস্টলের পর PowerShell বন্ধ করে নতুন করে খুলুন।** না করলে PATH আপডেট হবে না।

যাচাই:

```powershell
node -v
npm -v
```

দুইটাই ভার্সন নাম্বার দেখালে ঠিক আছে।

### ধাপ ২: dsh ইনস্টল

```powershell
npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh
```

`--allow-scripts` অংশটা জরুরি। `node-pty` আর `koffi` native binary বানায়; সেগুলো ছাড়া shell/terminal tool কাজ করবে না। **এটা মুছে ফেলবেন না** — npm ১২ থেকে install scripts ডিফল্টে বন্ধ, তাই এই allowlist ছাড়া native module গুলো বানেই না (error: `Failed to load native module`)।

শুধু টেস্ট করতে চাইলে ইনস্টল ছাড়াই:

```powershell
npx @deepseek-ai/dsh web
```

### ধাপ ৩: সার্ভার চালু

```powershell
dsh web
```

ডিফল্ট ঠিকানা: `http://127.0.0.1:3080`
Firewall পপআপ এলে **Allow access**।

**টার্মিনাল খোলা রাখুন** — বন্ধ করলে সার্ভারও বন্ধ। বন্ধ করতে Ctrl+C।

### ধাপ ৪: API key

**Settings → Models** খুলুন।

**DeepSeek** — কার্ডে একটাই key ফিল্ড। Key নিন https://platform.deepseek.com থেকে।

**Anthropic** — **Add provider** → Anthropic → key বসান। মডেল লিস্ট, endpoint, protocol নিজে থেকেই আসবে। Key নিন console.anthropic.com → API keys থেকে। কনসোলে ক্রেডিট থাকতে হবে; Claude.ai সাবস্ক্রিপশন দিয়ে API চলে না।

সেভ করলে রিস্টার্ট ছাড়াই কাজ করে। Key জমা হয় `%USERPROFILE%\.dsh\.credentials.yaml`-এ (`$DSH_HOME` = dsh-এর ডেটা ফোল্ডার = `%USERPROFILE%\.dsh`), write-only — পরে আর দেখা যায় না।

### ধাপ ৫: Workspace

**Choose workspace** ক্লিক করে প্রজেক্ট ফোল্ডার যোগ করুন। workspace সিলেক্ট না করা পর্যন্ত চ্যাট বক্স কাজ করবে না।

একাধিক workspace যোগ করে রাখা যায়, পরে UI থেকেই সুইচ করা যায়। **প্রতিবার প্রজেক্ট ফোল্ডারে গিয়ে dsh চালানোর দরকার নেই** — যে ফোল্ডার থেকে চালান সেটা শুধু ডিফল্ট সাজেশন।

### ধাপ ৬: টেস্ট

খালি একটা ফোল্ডার দিয়ে শুরু করুন, যেমন `C:\Users\<name>\dsh-test`। সেশন খুলে লিখুন: "একটা hello world Python স্ক্রিপ্ট বানাও"। ফাইল তৈরি হলে সেটআপ ঠিক আছে।

---

## অংশ ২ — macOS সেটআপ

macOS-এ **পুরো সেটআপ কাজ করে** — Figma ডেস্কটপ অ্যাপ Mac-এ আছে, তাই read-ও write-ও (Windows-এর মতোই)। ধাপগুলো Windows-এর মতো, শুধু প্যাকেজ ম্যানেজার আর পাথ আলাদা: `brew` আর `~` (= `/Users/<name>`), আর কীবোর্ড শর্টকাট `Cmd+/`।

### ধাপ ১: Node.js + Git (Homebrew)

```bash
brew install node git
```

`brew` না থাকলে আগে https://brew.sh থেকে install করে নিন। যাচাই:

```bash
node -v
git --version
```

### ধাপ ২: dsh ইনস্টল

```bash
npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh
```

`--allow-scripts` অংশটা জরুরি — অংশ ১ ধাপ ২-তে কেন, সেটা লেখা আছে।

### ধাপ ৩: env variable

`~/.zshrc`-এর শেষে যোগ করুন (macOS-এর ডিফল্ট শেল zsh):

```bash
export FIGMA_ACCESS_TOKEN="figd_..."
export ENABLE_MCP_APPS=true
```

তারপর `source ~/.zshrc` (বা নতুন terminal) দিয়ে যাচাই:

```bash
echo $FIGMA_ACCESS_TOKEN
```

### ধাপ ৪: API key

`dsh web` → `http://127.0.0.1:3080` → Settings → Models → Anthropic key বসান। Key জমা হয় `~/.dsh/.credentials.yaml`-এ, write-only।

### ধাপ ৫: কনফিগ কপি

```bash
mkdir -p ~/.dsh/profiles/web
cp cordis.patch.yml ~/.dsh/profiles/web/
```

ওই ফাইলে আগে থেকে কিছু থাকলে overwrite করবেন না, হাতে মার্জ করুন (অংশ ৬ ধাপ ৪)।

### ধাপ ৬: ব্রিজ প্লাগইন ইমপোর্ট

সার্ভার চালু হলে প্লাগইন ফাইল বানায়। যাচাই:

```bash
ls ~/.figma-console-mcp/plugin
```

`manifest.json`, `code.js`, `ui.html` থাকার কথা। তারপর Figma ডেস্কটপে ফাইল খুলে **`Cmd+/`** → টাইপ `import` → **Import plugin from manifest…** → `~/.figma-console-mcp/plugin/manifest.json` বেছে নিন। তারপর **Figma Desktop Bridge** চালান — সবুজ **Connected** দেখাবে।

(বিস্তারিত: অংশ ৬। সেখানে `%USERPROFILE%` আর `setx`-এর জায়গায় `~` আর `export` বসিয়ে পড়ুন।)

### যাচাই

```bash
./verify.sh
```

সবুজ হলে সেটআপ শেষ। প্রতি প্রজেক্টে `templates/AGENTS.md` কপি করতে ভুলবেন না (অংশ ৭)।

---

## অংশ ৩ — Linux (Ubuntu) সেটআপ

Linux-এ dsh আর কোডিং পুরো চলে, কিন্তু **Figma write নেই** — Figma ডেস্কটপ অ্যাপ Linux-এ নেই, তাই Desktop Bridge প্লাগইন ইমপোর্ট করা যায় না। Figma read (PAT দিয়ে) কাজ করে।

আলাদা Node লাগবে (ডিস্ট্রোর সাথে আসা Node প্রায়ই পুরনো):

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc
nvm install --lts
npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh
dsh web
```

`http://127.0.0.1:3080` ব্রাউজারে খুলবে।

**প্রজেক্ট রাখুন `~/projects/`-এ।** dsh workspace হিসেবে পুরো ফোল্ডার ট্রি পড়ে, তাই বড় জায়গা (যেমন হোম বা `/`) সিলেক্ট করবেন না।

Figma-সংক্রান্ত read-only টুল (ডিজাইন সিস্টেম, ভ্যারিয়েবল, কম্পোনেন্ট পড়া) PAT দিয়েই চলে — কিন্তু **লেখা বা ব্রিজ-নির্ভর টুল কাজ করবে না**। ডিজাইন তৈরি করতে হলে Windows বা Mac ব্যবহার করুন।

---

## অংশ ৪ — যা করবেন না

### অটো-স্টার্ট বসাবেন না

Startup ফোল্ডারে `.bat` রেখে ব্যাকগ্রাউন্ডে চালানোর পদ্ধতিটা **সমস্যা তৈরি করেছে** — মেমরি শেষ হয়ে PC হ্যাং করেছে।

কারণ: লুকানো উইন্ডোতে একাধিক ইনস্ট্যান্স জমতে পারে, আর এজেন্ট নিজেও সাবপ্রসেস চালায় (shell, sandbox, subagent)। সেশন লুপে পড়লে বা বড় ফোল্ডার ইনডেক্স করলে মেমরি দ্রুত বাড়ে। লুকানো থাকলে টেরই পাওয়া যায় না।

**অটো-স্টার্ট সরাতে:**

```powershell
explorer shell:startup
```

খোলা ফোল্ডার থেকে `dsh.bat` বা তার শর্টকাট ডিলিট করুন।

**আটকে যাওয়া প্রসেস মারতে:**

```powershell
taskkill /IM node.exe /F
```

(সব Node প্রসেস মারবে।) অথবা Ctrl+Shift+Esc → Task Manager → `node.exe` → End task।

### বড় ফোল্ডার workspace বানাবেন না

`C:\Users\<name>` বা Desktop সিলেক্ট করবেন না। এজেন্ট workspace-এর ফাইল পড়তে ও বদলাতে পারে, আর বড় ট্রি মেমরি খায়।

---

## অংশ ৫ — নিরাপদ ব্যবহারের নিয়ম

- **হাতে চালু, কাজ শেষে বন্ধ।** টার্মিনাল দেখতে পেলে বুঝবেন কী হচ্ছে; Ctrl+C দিয়ে সাথে সাথে থামানো যায়।
- প্রথম কয়েকটা সেশনে **Task Manager খুলে রেখে `node.exe`-এর মেমরি দেখুন**। বাড়তে থাকলে Ctrl+C।
- ছোট, আলাদা workspace দিয়ে শুরু করুন।
- সার্ভার `127.0.0.1`-এ বাঁধা — শুধু ওই PC থেকেই অ্যাক্সেস, নেটওয়ার্কের অন্য কেউ পাবে না।

---

## অংশ ৬ — Figma ইন্টিগ্রেশন (create / edit / read)

এজেন্ট দিয়ে Figma-তে ডিজাইন তৈরি, এডিট ও পড়া — সবই dsh থেকে।

### যা কাজ করে না (সময় নষ্ট করবেন না)

Figma-র অফিশিয়াল রিমোট MCP (`https://mcp.figma.com/mcp`) **dsh-এ চলবে না**। কারণ:

- Figma শুধু OAuth নেয়, PAT নেয় না
- Figma dynamic client registration খোলা রাখে না — শুধু প্রি-রেজিস্টার্ড ক্লায়েন্ট (VS Code, Cursor, Claude Code, Codex) ঢুকতে পারে
- OAuth-ক্ষম কমিউনিটি প্লাগইন (dsh-mcp-manager) দিয়ে চেষ্টা → `client registration failed: HTTP 403 Forbidden`
- mcp-remote ব্রিজ দিয়ে চেষ্টা → একই জায়গায় ব্যর্থ (`registerClient`, JSON-এর বদলে HTML এরর পেজ)

### যা কাজ করে — figma-console-mcp (Local Mode)

OAuth দেয়াল টপকানোর বদলে পাশ কাটানো। Figma-র Plugin API-তে লেখার পূর্ণ ক্ষমতা আছে, আর সেটা চলে ডেস্কটপ অ্যাপের ভেতরে যেখানে আপনি এমনিতেই লগইন। একটা ব্রিজ প্লাগইন localhost WebSocket-এ MCP সার্ভারের সাথে কথা বলে।

**১২৫টা টুল, পূর্ণ read/write।** Plugin API ব্যবহার করে বলে Free/Pro প্ল্যানেও variable কাজ করে।

### ধাপ ১: প্রয়োজনীয় জিনিস

**Figma ডেস্কটপ অ্যাপ** (ব্রাউজার নয় — প্লাগইন ইমপোর্টের জন্য দরকার)। ব্যস, আর কিছু না।

> **আগের ভার্সনে `dsh-mcp-manager` প্লাগইন লাগত।** পরীক্ষা করে দেখা গেছে **লাগে না** — dsh-এর বিল্ট-ইন MCP ক্লায়েন্টই যথেষ্ট। তাই pnpm, git-hosted প্লাগইন ইনস্টল, আর UI ফর্ম ভরার ধাপগুলো বাদ দেওয়া হয়েছে।

### ধাপ ২: Figma Personal Access Token

figma.com → প্রোফাইল → Settings → Security → Personal access tokens → Generate new token

Expiration যা খুশি (৯০ দিন ঠিক আছে)। স্কোপগুলো Figma-র স্ক্রিনে যে ক্রমে আসে সেই ক্রমে টিক দিন:

| সেকশন              | স্কোপ                          |
| ------------------ | ------------------------------ |
| **Users**          | ✅ `current_user:read`         |
| **Files**          | ✅ `file_comments:read`        |
|                    | ✅ `file_comments:write`       |
|                    | ✅ `file_content:read`         |
|                    | ✅ `file_metadata:read`        |
|                    | ✅ `file_versions:read`        |
| **Design systems** | ✅ `library_assets:read`       |
|                    | ✅ `library_content:read`      |
|                    | ✅ `team_library_content:read` |
| **Development**    | ✅ `file_dev_resources:read`   |
|                    | ✅ `file_dev_resources:write`  |
| **Folders**        | ✅ `folders:read`              |
| **Webhooks**       | ❌ দুইটাই বাদ — কাজে লাগবে না  |

ভ্যারিয়েবলের জন্য REST-এ `file_variables:read` / `file_variables:write` স্কোপ আছে, কিন্তু সেগুলো **Enterprise প্ল্যানে সীমাবদ্ধ** — এখানে টিক দেবেন না। ভ্যারিয়েবল এই সেটআপে Plugin API দিয়ে পড়া-লেখা হয় (ব্রিজ প্লাগইন), REST দিয়ে না — এজন্যই Free/Pro প্ল্যানেও কাজ করে।

টোকেন `figd_` দিয়ে শুরু, **একবারই দেখাবে** — সাথে সাথে কপি করুন।

> **স্কোপ নিয়ে বিভ্রান্তি এড়াতে:** টোকেনের write scope-গুলো শুধু comment আর dev resource-এর জন্য (table-তে ✅ যেগুলো)। **ডিজাইন-কনটেন্ট** (frame, layer, component, variable) তৈরি বা বদলানো REST দিয়ে হয়ই না — সেটা ব্রিজ প্লাগইনের (Plugin API) কাজ। তাই ডিজাইন লেখার ক্ষমতা প্লাগইন দেয়, টোকেন দিয়ে নয়।

**টোকেন কখনো ফাইলে বা স্ক্রিনশটে রাখবেন না।** প্রকাশ পেলে সাথে সাথে figma.com → Settings → Security-তে গিয়ে revoke করে নতুন বানান।

### ধাপ ৩: env variable সেট করুন

cmd-তে:

```
setx FIGMA_ACCESS_TOKEN "figd_..."
setx ENABLE_MCP_APPS true
```

**cmd বন্ধ করে নতুন করে খুলুন**, তারপর যাচাই:

```
echo %FIGMA_ACCESS_TOKEN%
```

টোকেন দেখালে ঠিক আছে। `%FIGMA_ACCESS_TOKEN%` হুবহু ফেরত এলে সেট হয়নি।

npx প্রসেস সিস্টেমের env উত্তরাধিকারসূত্রে পায়, তাই কনফিগে আলাদা করে env লিখতে হয় না।

### ধাপ ৪: কনফিগ ফাইল

টিম রিপো ব্যবহার করলে সহজ পথ — শুধু কপি:

```
mkdir "%USERPROFILE%\.dsh\profiles\web" 2>nul
copy cordis.patch.yml "%USERPROFILE%\.dsh\profiles\web\"
```

**ওই ফাইলে আগে থেকে কিছু থাকলে overwrite করবেন না**, হাতে মার্জ করুন।

হাতে করতে চাইলে:

```
notepad %USERPROFILE%\.dsh\profiles\web\cordis.patch.yml
```

ফাইলে যদি শুধু `[]` থাকে, সেটা মুছে নিচেরটা বসান (উপরের কমেন্ট লাইনগুলো রেখে দিন):

```yaml
- insert:
    - id: mcp-figma
      name: "@deepseek-ai/dsh-mcp-client"
      config:
        serverName: figma
        transport: stdio
        command: npx
        args: ["-y", "figma-console-mcp@latest"]
```

**ইন্ডেন্টেশন হুবহু রাখুন** — YAML স্পেসের ব্যাপারে কড়া, ট্যাব চলবে না।

সেভ করে dsh রিস্টার্ট করুন। যে window-এ `dsh web` চলছে সেখানে **Ctrl+C** দিয়ে বন্ধ করুন, তারপর আবার চালান:

```
dsh web
```

(কনফিগ বদলানো রিস্টার্ট ছাড়া কার্যকর হয় না। Ctrl+C কাজ না করলে — dsh আটকে গেলে — তখনই `taskkill /IM node.exe /F`; অংশ ৪ দেখুন।)

### ধাপ ৫: ব্রিজ প্লাগইন ইমপোর্ট

সার্ভার চালু হলে নিজেই প্লাগইন ফাইল বানায়। যাচাই:

```
dir %USERPROFILE%\.figma-console-mcp\plugin
```

`manifest.json`, `code.js`, `ui.html` থাকার কথা।

Figma ডেস্কটপে একটা ফাইল খুলে **`Ctrl+/`** → টাইপ `import` → **Import plugin from manifest…** বেছে নিন।

(Tools প্যানেলের Create মেনুতে এই অপশন নেই — ওটা নতুন প্লাগইন বানানোর জন্য। quick actions-ই একমাত্র নির্ভরযোগ্য পথ।)

পাথ:

```
%USERPROFILE%\.figma-console-mcp\plugin\manifest.json
```

ইমপোর্টের পর **Figma Desktop Bridge** চালান। প্লাগইন উইন্ডোতে সবুজ **Connected — Connected to 1 AI app** দেখাবে। একবার ইমপোর্ট করলেই যথেষ্ট।

### চালু রাখার শর্ত

তিনটা একসাথে চালু থাকতে হবে:

1. **dsh সার্ভার**
2. **Figma ডেস্কটপ**
3. **ব্রিজ প্লাগইন উইন্ডো**

যেকোনো একটা বন্ধ হলে লেখার টুল কাজ করবে না। প্লাগইন উইন্ডোটা ক্যানভাসের কোণে সরিয়ে রাখুন।

সেশন **Standard বা Code mode**-এ হতে হবে — Minimal mode MCP টুল দেখায় না।

### গুরুত্বপূর্ণ: স্ক্রিনশট টুল ভাঙা

`figma_capture_screenshot` এবং `figma_take_screenshot` এই সেটআপে কাজ করে না — `Cannot read properties of undefined (reading 'bytes')`।

**কারণ:** আগে Local Mode-এ Chrome DevTools Protocol ট্রান্সপোর্ট ছিল, স্ক্রিনশট ওটা দিয়েই হতো। ডেভেলপার সেটা সরিয়ে ফেলেছেন — এখন WebSocket ব্রিজই একমাত্র Local পথ। কিন্তু স্ক্রিনশট/navigate/console টুলগুলো এখনো Cloud Mode-এর browser rendering-নির্ভর। তাই Local Mode-এ কোডপথটাই নেই।

**ফিক্স নেই।** `--remote-debugging-port=9222` দিয়ে Figma চালিয়েও লাভ হবে না, ওই কোড আর নেই। ভবিষ্যতে ফিরতে পারে — `@latest` দেওয়া আছে বলে আপডেট নিজে থেকেই আসবে।

**সবচেয়ে বড় বিপদ:** একবার ব্যর্থ হলে পুরো সেশন দূষিত হয়ে যায়। এরপর টুল কল ছাড়াই প্রতি টার্নে একই এরর আসতে থাকে। সারানোর উপায় নেই — **New Session** খুলতে হবে।

**সমাধান:** workspace-এ `AGENTS.md` রাখুন (অংশ ৭ দেখুন)। সেখানে নিয়ম লেখা থাকলে এজেন্ট এই টুলে হাতই দেবে না।

### ছবি দেখা নিয়ে

dsh ইনলাইন ছবি রেন্ডার করতে পারে না (`unsupported content type "image/png"`), আর শেল দিয়ে Figma image URL ডাউনলোডও এই পরিবেশে ব্যর্থ হয়।

তাই ভিজ্যুয়াল যাচাইয়ের ভার এজেন্টকে দেবেন না। **Figma ডেস্কটপ পাশেই খোলা — চোখ ঘুরিয়ে দেখে নিন।** এটাই দ্রুততম এবং কিছু ভাঙার সুযোগও নেই।

খুব দরকার হলে `figma_get_component_image` দিয়ে URL নিয়ে ব্রাউজারে খুলুন। URL দ্রুত মেয়াদোত্তীর্ণ হয়।

### টেস্ট

```
figma_diagnose চালিয়ে কানেকশনের অবস্থা দেখাও
```

```
Test AI ফাইলে একটা 200x100 নীল rectangle বানাও। স্ক্রিনশট নেবে না।
```

ক্যানভাসে তৈরি হলে সব ঠিক।

### সতর্কতা

**টেস্ট ফাইলে কাজ করুন, আসল প্রজেক্ট ফাইলে নয়।** এজেন্ট Figma-তে লিখতে পারে মানে ভুলও করতে পারে, আর Figma-র undo history এজেন্টের বড় অপারেশনের সাথে সবসময় ভালো চলে না।

---

## অংশ ৭ — প্রজেক্ট সেটআপ ও কাজের প্রবাহ

### প্রতি প্রজেক্টে যা করবেন

```
mkdir %USERPROFILE%\projects\my-site
cd %USERPROFILE%\projects\my-site
git init
copy %USERPROFILE%\dsh-setup\templates\AGENTS.md .
REM উপরের পথটা ধরে নিয়েছে dsh-setup রিপোটা %USERPROFILE%-এ clone করা। অন্য জায়গায় থাকলে পথ বদলে নিন।
```

তারপর dsh UI-তে **Choose workspace** দিয়ে ফোল্ডারটা যোগ ও সিলেক্ট করুন। সার্ভার রিস্টার্ট লাগে না।

**git init করবেনই।** এজেন্ট ফাইল বদলাবে, কখনো ভুলও করবে। `git diff` দিয়ে দেখতে পারবেন কী বদলাল, খারাপ হলে ফিরিয়ে আনতে পারবেন।

### AGENTS.md

workspace ফোল্ডারে `AGENTS.md` রাখলে এজেন্ট সেশন শুরুতে সেটা পড়ে নেয়। Figma-র ভাঙা টুলগুলো এড়াতে এটাই সবচেয়ে কার্যকর উপায় — প্রতি সেশনে হাতে মনে করিয়ে দিতে হয় না।

**প্রতি প্রজেক্টে আলাদা কপি লাগে** — workspace-ভিত্তিক, গ্লোবাল নয়।

ফাইলে যে নিয়মগুলো থাকা দরকার:

- `figma_capture_screenshot` / `figma_take_screenshot` কখনো ব্যবহার না করা, এবং কেন (সেশন নষ্ট হয়)
- ছবি ইনলাইন দেখানো বা শেল দিয়ে ডাউনলোড না করা
- ভিজ্যুয়াল যাচাই ব্যবহারকারীর কাজ; এজেন্ট শুধু node id, লেয়ারের নাম, পজিশন জানাবে
- লেখার আগে `figma_get_status` দিয়ে সক্রিয় ফাইল যাচাই
- `figma_navigate`-এ ফাইলের নাম নয়, URL লাগে
- ধ্বংসাত্মক কাজের আগে অনুমতি নেওয়া

নিয়মের সাথে **কারণ** লিখবেন। এজেন্ট কারণ জানলে নিয়ম বেশি মানে, অজুহাত খুঁজে ভাঙে না।

### সেশন নিয়ে

**প্রতি কাজের জন্য নতুন সেশন।** কনটেক্সট পরিষ্কার থাকে, খরচ কমে, একটা কাজের ভুল পরেরটায় যায় না।

AGENTS.md বদলালে নতুন সেশন লাগবে — চলমান সেশন পুরনো কপি ধরে রাখে।

মোড **Standard বা Code**-এ চালান — Minimal mode MCP টুল দেখায় না (বিস্তারিত: অংশ ৬-এর "চালু রাখার শর্ত")।

### Figma → কোড

**১.** Figma ডেস্কটপে ফ্রেম সিলেক্ট করুন
**২.** Desktop Bridge প্লাগইন চালু আছে নিশ্চিত করুন (সবুজ Connected)
**৩.** dsh-এ নতুন সেশনে বলুন:

```
Figma-তে এখন যে ফ্রেমটা সিলেক্ট করা আছে সেটা পড়ে responsive HTML + Tailwind বানাও।
- আগে figma_get_status দিয়ে কানেকশন যাচাই করো
- সেমান্টিক HTML, মোবাইল-ফার্স্ট, sm/md/lg breakpoint
- Tailwind CDN দিয়ে index.html বানাও
- কাজ শেষে কী কী তৈরি করলে বলো
```

**৪.** ব্রাউজারে খুলে দেখুন: `start index.html`
**৫.** একই সেশনে সংশোধন চালিয়ে যান

সিলেক্ট করা নোড ধরতে না পারলে Figma-তে লেয়ারে ডান-ক্লিক → **Copy link to selection**, URL-এর `node-id` দিয়ে বলুন।

### ভালো ফল পেতে

**Auto layout ব্যবহার করুন** — সবচেয়ে বড় পার্থক্য এটাই। Auto layout সরাসরি flex/grid-এ অনুবাদ হয়। Absolute positioning-এর ডিজাইন হলে এজেন্ট আন্দাজে responsive বানাবে।

**লেয়ারের নাম অর্থপূর্ণ রাখুন** — `Frame 47` নয়, `header`, `card-grid`, `cta-button`। এজেন্ট নাম দেখে সেমান্টিক ট্যাগ বাছে।

**টোকেন আগে টানুন** — বড় কাজের আগে একবার `figma_get_variables` দিয়ে `tailwind.config.js` বানিয়ে নিন, তারপর কম্পোনেন্ট একে একে। সব একসাথে চাইলে মান কমে যায়।

**একাধিক breakpoint-এর ফ্রেম রাখুন** — Figma-তে সাধারণত এক সাইজের ডিজাইন থাকে, তাই responsive আচরণ এজেন্টের অনুমান। ডেস্কটপ ও মোবাইল দুইটা ফ্রেম দেখাতে পারলে ফল অনেক ভালো।

### যা আশা করবেন না

পিক্সেল-পারফেক্ট আউটপুট প্রথমবারেই আসবে না। Figma-র লেআউট মডেল আর CSS-এর মডেল এক নয় — টেক্সট রেন্ডারিং, shadow, nested constraint-এ পার্থক্য থাকবে। কয়েক দফা সংশোধন লাগবে, সেটাই স্বাভাবিক।

---

## অংশ ৮ — Troubleshooting

**কিছু কাজ না করলে আগে যাচাই স্ক্রিপ্টটা চালান** — কোন অংশটা নেই সেটা সরাসরি বলে দেবে:

```
verify.bat          # Windows
./verify.sh         # macOS / Linux
```

> **নোট (Windows):** `setx`-এর পর **একই window-এ** verify চালালে `FIGMA_ACCESS_TOKEN`-এ মিথ্যে `[FAIL]` দেখাবে — `setx` শুধু নতুন terminal-কে প্রভাবিত করে। window বন্ধ করে নতুন cmd খুলে আবার চালান।

তারপর নিচের টেবিল।

| সমস্যা                                                                     | সমাধান                                                                                                                                                               |
| -------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `'node' is not recognized`                                                 | টার্মিনাল রিস্টার্ট করুন। না হলে: `$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")` |
| `npm.ps1` / `npx.ps1 cannot be loaded because running scripts is disabled` | PowerShell-এর execution policy আটকাচ্ছে। cmd-তে চালান (Win+R → `cmd`), অথবা একবার: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`                             |
| `Cannot find module` / `.node file not found`                              | `--allow-scripts` দিয়ে আবার ইনস্টল করুন (ধাপ ২)                                                                                                                     |
| পোর্ট 3080 ব্যস্ত                                                          | `netstat -ano \| findstr 3080` দিয়ে দেখুন কে ধরে আছে                                                                                                                |
| `MISSING_CREDENTIAL`                                                       | Models পেজে key সেভ হয়নি                                                                                                                                            |
| `UNKNOWN_MODEL`                                                            | কনফিগার করা মডেল সিলেক্ট করুন                                                                                                                                        |
| Fetch models → 401                                                         | Key ভুল বা ক্রেডিট নেই                                                                                                                                               |
| PC হ্যাং / মেমরি ফুল                                                       | `taskkill /IM node.exe /F`, অটো-স্টার্ট সরান                                                                                                                         |
| `client registration failed: HTTP 403` (Figma OAuth)                       | Figma dynamic client registration মানে না। অফিশিয়াল রিমোট MCP dsh-এ চলবে না — figma-console-mcp ব্যবহার করুন                                                        |
| `Cannot read properties of undefined (reading 'bytes')`                    | স্ক্রিনশট টুল ভাঙা। সেশন দূষিত — **New Session** খুলুন                                                                                                               |
| `figma_get_status` টুলই নেই                                                | ১) `cordis.patch.yml`-এর ইন্ডেন্টেশন দেখুন (ট্যাব নয়, স্পেস)। ২) Windows-এ হলে `command: npx` → `command: npx.cmd` চেষ্টা করুন। তারপর dsh রিস্টার্ট |
| Figma টোকেন পাচ্ছে না                                                      | `setx`-এর পর নতুন cmd থেকে dsh চালিয়েছেন কি না দেখুন                                                                                                                |
| Figma লেখার টুল কাজ করছে না                                                | ব্রিজ প্লাগইন উইন্ডো বন্ধ, বা Figma ডেস্কটপ বন্ধ, বা Minimal mode-এ আছেন                                                                                             |

`deprecated node-domexception` warning উপেক্ষা করা যায়। npm আপডেটের notice-ও ঐচ্ছিক।

---

## অংশ ৯ — নতুন PC-তে সেটআপ চেকলিস্ট

শূন্য থেকে পুরো সিস্টেম দাঁড় করাতে এই ক্রমে যান। প্রতিটার বিস্তারিত উপরের অংশগুলোতে।

**প্রস্তুতি**

- [ ] Figma ডেস্কটপ অ্যাপ ইনস্টল ও লগইন করা আছে
- [ ] cmd ব্যবহার করছেন (PowerShell নয়) — নইলে execution policy ঠিক করে নিন

**ইনস্টল (সব cmd-তে)**

- [ ] `winget install OpenJS.NodeJS.LTS` → **টার্মিনাল রিস্টার্ট** → `node -v` যাচাই
- [ ] `winget install Git.Git` → **টার্মিনাল রিস্টার্ট** → `git --version` যাচাই
- [ ] `npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh`

**dsh কনফিগ**

- [ ] `dsh web` → `http://127.0.0.1:3080` → Settings → Models → Anthropic key বসান
- [ ] `setx FIGMA_ACCESS_TOKEN "figd_..."` এবং `setx ENABLE_MCP_APPS true`
- [ ] **নতুন cmd** খুলে `echo %FIGMA_ACCESS_TOKEN%` যাচাই
- [ ] রিপোর `cordis.patch.yml` কপি করুন `%USERPROFILE%\.dsh\profiles\web\`-এ (অংশ ৬ ধাপ ৪)
- [ ] dsh রিস্টার্ট → সেশনে `figma_get_status` কাজ করে

**Figma ব্রিজ**

- [ ] `dir %USERPROFILE%\.figma-console-mcp\plugin` → manifest.json আছে
- [ ] Figma ডেস্কটপে `Ctrl+/` → `import` → Import plugin from manifest…
- [ ] প্লাগইন চালু → সবুজ **Connected — Connected to 1 AI app**

**প্রজেক্ট**

- [ ] ফোল্ডার বানান, `git init`, `templates/AGENTS.md` কপি করুন
- [ ] dsh-এ Choose workspace দিয়ে যোগ ও সিলেক্ট
- [ ] New Session, Standard mode → `figma_diagnose` দিয়ে টেস্ট

### যেসব জিনিস শেয়ার করা যায়

- **Figma PAT** — একটা বানিয়ে সব PC-তে ব্যবহার করা যায়। মেয়াদ শেষ হলে সবগুলোতেই বদলাতে হবে।
- **AGENTS.md** — কপি করে নিলেই হয়।

### যেসব যায় না

- **API key স্বয়ংক্রিয়ভাবে** — প্রতি মেশিনে UI থেকে বসাতে হবে, `$DSH_HOME` আলাদা।
- **ব্রিজ প্লাগইন** — প্রতি মেশিনে আলাদা করে ইমপোর্ট।

### সতর্কতা

**আগে এক PC-তে কয়েকদিন চালিয়ে দেখুন**, তারপর ছড়ান। dsh dev preview, Figma-ও ঘন ঘন UI বদলায় — এক মাস পরে বোতামের জায়গা এক না-ও থাকতে পারে।

দ্বিতীয় PC-তে এই ডকুমেন্ট ধরে করার সময় যেখানে বাস্তবতা মেলে না, **সেখানেই ডকুমেন্ট আপডেট করে নিন**। তারপর টিমের বাকিদের যাচাই করা ভার্সনটা দেবেন।

আপডেট:

```powershell
npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh
```

**`npm update -g` ব্যবহার করবেন না** — এটা `--allow-scripts` allowlist পুনরায় প্রয়োগ করে না, ফলে native module (node-pty, koffi) বানানো ছাড়া থেকে যায় (`Cannot find module` / `.node file not found` error — অংশ ৮ দেখুন)। উপরের install command-ই আপডেটের সঠিক উপায়, আর বারবার চালানো নিরাপদ — ইতিমধ্যে latest থাকলে কিছুই বদলায় না।

---

## দ্রুত রেফারেন্স

**চালু করার ক্রম**

```powershell
# ১. dsh সার্ভার
dsh web
# ২. ব্রাউজারে http://127.0.0.1:3080
# ৩. Figma ডেস্কটপ খুলুন
# ৪. Ctrl+/ → "Figma Desktop Bridge" চালান
# ৫. dsh-এ New Session, workspace সিলেক্ট, Standard mode
```

**তিনটা একসাথে চালু থাকতে হবে:** dsh সার্ভার · Figma ডেস্কটপ · ব্রিজ প্লাগইন উইন্ডো

**কমান্ড**

```
dsh web                              # চালু
Ctrl+C (dsh-এর window-এ)             # বন্ধ
npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh   # আপডেট (npm update নয় — অংশ ৯)
dir %USERPROFILE%\.figma-console-mcp\plugin   # প্লাগইন ফাইল চেক
```

**পাথ**

```
%USERPROFILE%\.dsh\profiles\web\cordis.patch.yml   # dsh কনফিগ
%USERPROFILE%\.dsh\.credentials.yaml               # API key (write-only)
%USERPROFILE%\.figma-console-mcp\plugin\manifest.json   # ব্রিজ প্লাগইন
<workspace>\AGENTS.md                            # এজেন্টের নিয়ম
```
