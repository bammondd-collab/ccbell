# ccbell

**A doorbell for your Claude Code sessions on Windows.** A small always-on-top capsule at the edge
of the screen shows how many sessions **need input**, are **done** and are **running**, rings when
one finishes or waits for you, and jumps back to the VS Code terminal tab that shows it.

**Claude Code 세션 초인종 (Windows).** 화면 끝의 작은 캡슐이 입력 필요 · 완료 · 진행 중 세션 수를
보여 주고, 끝나거나 내 답을 기다리면 알려 줘요. 누르면 그 세션이 열린 VS Code 터미널 탭으로 바로 갑니다.

## Install · 설치

Windows 10/11 (64-bit) with Claude Code. No admin rights. Open **PowerShell** and paste:

```powershell
irm https://raw.githubusercontent.com/bammondd-collab/ccbell/master/scripts/install.ps1 | iex
```

PowerShell 을 열고 위 한 줄을 붙여 넣으면 끝이에요(관리자 권한 필요 없음). 설치기는 받은 파일의
SHA-256 지문을 확인하고, 다르면 아무것도 설치하지 않아요.

Offline: download `ccbell-win-x64.zip` from [Releases](https://github.com/bammondd-collab/ccbell/releases),
unzip it and double-click `Install.cmd`. If you use VS Code, reload its window once after installing.

The installer copies the app to `%LOCALAPPDATA%\Programs\ccbell`, registers it in the Start menu and
Settings > Apps, adds two hooks (Stop, Notification) to `~/.claude/settings.json` (only its own entries,
after a backup), installs the small VS Code bridge extension when `code` is available, and starts with Windows.

## Use · 쓰는 법

| Capsule | Meaning |
|---|---|
| orange **?** | needs input: a permission prompt or a question · 입력 필요 |
| green **✓** | finished and not looked at yet · 완료(안 본 것) |
| blue **↻** | Claude is working · 진행 중 |

Hover or click the capsule for the list. **Continue / Open** jumps to the session's VS Code terminal tab;
**Other ways** opens a new Windows Terminal, claude.ai/code, the folder, or stops the session. Korean and
English follow the Windows language (change it in the settings).

## Privacy · 개인정보

ccbell reads Claude Code's own files in `~/.claude` on your PC and **sends nothing over the internet**.
The only listener is `127.0.0.1:7789`, for the hook. 이 PC 밖으로 아무것도 보내지 않아요.

## Uninstall · 지우기

**Settings > Apps > Installed apps > ccbell > Uninstall.** It removes the hooks (only ccbell's entries,
with a backup), the VS Code extension, the shortcut and the start-with-Windows entry.

## Notes

- Not code-signed yet. The one-line install usually shows no warning; for the zip, choose
  *More info → Run anyway* if Windows asks.
- Node.js is not required. Windows only for now.
- ccbell is an independent project, not affiliated with Anthropic. Claude and Claude Code are
  trademarks of Anthropic.

See [LICENSE](LICENSE) for the terms of use.
