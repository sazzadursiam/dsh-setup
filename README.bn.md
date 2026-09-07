> **English:** see [`README.md`](README.md) · পূর্ণ গাইড [`SETUP.md`](SETUP.md)

# dsh + Figma — টিম সেটআপ

নতুন PC-তে DeepSeek Harness আর Figma ইন্টিগ্রেশন বসানোর জন্য।

## দ্রুত শুরু

**Windows** — Command Prompt-এ (PowerShell নয়):

```
git clone https://github.com/sazzadursiam/dsh-setup.git
cd dsh-setup
setup.bat
```

**Mac / Ubuntu** (Linux):

```bash
git clone https://github.com/sazzadursiam/dsh-setup.git
cd dsh-setup
chmod +x setup.sh
./setup.sh
```

স্ক্রিপ্ট Node.js, Git আর dsh বসিয়ে দেবে। বাকি ধাপগুলো (টোকেন, কনফিগ কপি, Figma প্লাগইন) শেষে স্ক্রিনে দেখাবে।

**Windows-এ Node বা Git নতুন করে ইনস্টল হলে স্ক্রিপ্ট থেমে যাবে** — উইন্ডো বন্ধ করে নতুন Command Prompt খুলে আবার `setup.bat` চালান। Windows নতুন PATH শুধু নতুন টার্মিনালেই দেখে।

## প্ল্যাটফর্ম অনুযায়ী কী পাবেন

|                     | Windows | Mac | Ubuntu |
| ------------------- | ------- | --- | ------ |
| dsh + কোডিং         | ✅      | ✅  | ✅     |
| Figma read (PAT)    | ✅      | ✅  | ✅     |
| Figma write (ব্রিজ) | ✅      | ✅  | ❌     |

**Linux-এ Figma ডেস্কটপ অ্যাপ নেই**, আর ব্রিজ প্লাগইন ডেস্কটপ ছাড়া ইমপোর্ট করা যায় না। তাই Ubuntu-তে ডিজাইন তৈরি বা এডিট করা যাবে না — শুধু পড়া যাবে।

## এরপর হাতে যা করতে হবে

স্ক্রিপ্ট শেষে ধাপগুলো স্ক্রিনে দেখাবে। সংক্ষেপে:

1. Figma টোকেন env variable-এ সেট করুন (`setx` বা `export`)
2. `cordis.patch.yml` dsh প্রোফাইলে কপি করুন
3. `dsh web` → Anthropic API key বসান (Settings → Models)
4. Figma ডেস্কটপে ব্রিজ প্লাগইন ইমপোর্ট করুন
5. প্রতি প্রজেক্টে `templates/AGENTS.md` কপি করুন

বিস্তারিত `SETUP.bn.md`-তে — ধাপে ধাপে নির্দেশ, troubleshooting টেবিল, আর কোন পথগুলো কাজ করে না (যাতে সময় নষ্ট না হয়)। ইংরেজি পড়তে চাইলে `SETUP.md`।

## ফাইলগুলো

| ফাইল                       | কী                                                    |
| -------------------------- | ----------------------------------------------------- |
| `setup.bat`                | ইনস্টল স্ক্রিপ্ট — Windows                            |
| `setup.sh`                 | ইনস্টল স্ক্রিপ্ট — Mac, Ubuntu (Linux)            |
| `verify.bat` / `verify.sh` | কী সেট আছে, কী নেই — যাচাই                            |
| `cordis.patch.yml`         | Figma MCP কনফিগ — dsh প্রোফাইলে কপি করতে হবে          |
| `SETUP.bn.md`              | পূর্ণ গাইড (বাংলা) — সেটআপ, workflow, troubleshooting  |
| `SETUP.md`                 | পূর্ণ গাইড (English) — সেটআপ, workflow, troubleshooting |
| `templates/AGENTS.md`      | এজেন্টের নিয়ম — প্রতি প্রজেক্ট ফোল্ডারে কপি করতে হবে |
| `.env.example`             | কোন env variable লাগে তার তালিকা                      |
| `CHANGELOG.md`             | কী বদলেছে                                             |

`SETUP.bn.md`-এ Windows, macOS (অংশ ২) আর Linux/Ubuntu (অংশ ৩) — তিনটার আলাদা সেকশন আছে। Windows-এর কমান্ডগুলো cmd-ভিত্তিক; Mac/Linux-এ পাথ `~/` দিয়ে শুরু হবে (`%USERPROFILE%` নয়), আর কীবোর্ড শর্টকাট Mac-এ `Cmd+/`।

## টোকেন

**রিপোতে কোনো টোকেন রাখবেন না।** প্রতি মেশিনে UI থেকে বসাতে হবে।

- Anthropic key — console.anthropic.com
- Figma PAT — figma.com → Settings → Security (স্কোপ `SETUP.bn.md`-তে)

Figma PAT একটাই সব মেশিনে ব্যবহার করা যায়। মেয়াদ শেষ হলে সবগুলোতে বদলাতে হবে।

## জানা সমস্যা

**স্ক্রিনশট টুল কাজ করে না।** `figma_capture_screenshot` ব্যর্থ হয়, আর একবার ব্যর্থ হলে পুরো সেশন নষ্ট হয়ে যায় — নতুন সেশন খোলা ছাড়া উপায় নেই। `templates/AGENTS.md` এই টুল ব্যবহার করা থেকে এজেন্টকে আটকায়, তাই প্রতি প্রজেক্টে ফাইলটা রাখা জরুরি।

**dsh developer preview।** breaking change আসতে পারে। কিছু ভাঙলে `SETUP.bn.md`-এর troubleshooting দেখুন, আর যা শিখলেন সেটা ডকুমেন্টে যোগ করে দিন।

## অবদান

নতুন PC-তে সেটআপ করার সময় ডকুমেন্টের সাথে বাস্তবতা না মিললে — ঠিক করে PR দিন। এভাবেই গাইডটা কাজের থাকবে।

## লেখক

Sazzadur Rahman

## লাইসেন্স

MIT — `LICENSE` দেখুন।
