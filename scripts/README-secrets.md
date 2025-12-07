# 生成与上传证书/配置文件到 GitHub Secrets（说明）

本说明适用于 `scripts/generate_secrets.sh`，该脚本已添加到仓库，用于把本地的 `.p12`（签名证书）和 `.mobileprovision`（可选）文件编码为单行 base64，方便复制到 GitHub Secrets 或通过 `gh` CLI 自动上传。

目的
- 生成单行 base64（没有换行）以便安全地放入 GitHub Actions Secrets。
- 提供可选一步将生成的 base64 自动上传到 GitHub 仓库 Secrets（需要 `gh` CLI 登录）。

注意（重要）
- 切勿将 base64 文件或原始 `.p12`/`.mobileprovision` 提交到版本控制。脚本默认输出目录 `./secrets-out`，请在上传后立即删除其中的敏感文件。
- 请仅在私有或受信环境下操作证书与私钥。

脚本位置
- `scripts/generate_secrets.sh`

快速用法示例

1) 只生成单行 base64 文件（不上传）

```bash
# 在仓库根目录执行：
./scripts/generate_secrets.sh --p12 path/to/signcert.p12 --profile path/to/profile.mobileprovision --out-dir ./out
# 输出会写到 ./out 目录
```

2) 复制 p12 的 base64 到剪贴板（macOS）

```bash
./scripts/generate_secrets.sh --p12 path/to/signcert.p12 --copy
# 剪贴板里的内容可直接粘贴到 GitHub Secret 的输入框
```

3) 使用 gh CLI 自动上传到仓库（必须先运行 `gh auth login` 并确保有权限）

```bash
# 上传到当前仓库（在仓库根目录执行）
./scripts/generate_secrets.sh --p12 path/to/signcert.p12 --p12-pass "你的_p12_密码" --upload

# 或上传到特定仓库 owner/repo
./scripts/generate_secrets.sh --p12 path/to/signcert.p12 --p12-pass "你的_p12_密码" --upload owner/repo
```

脚本会生成并（可选）上传的 Secrets 名称（默认前缀 `APP`，可通过 `--gh-prefix` 修改）
- `APP_CERT_P12_BASE64` — .p12 单行 base64
- `APP_CERT_P12_PASSWORD` — .p12 密码（明文 secret）
- `APP_PROV_PROFILE_BASE64` — provisioning profile 的 base64（可选，macOS 通常不需要）

如何手动在 GitHub UI 中添加 Secrets
1. 仓库 → Settings → Secrets and variables → Actions → New repository secret
2. 新增如下 secrets：
   - 名称：`APP_CERT_P12_BASE64` 值：把生成的单行 base64 粘贴进去
   - 名称：`APP_CERT_P12_PASSWORD` 值：你的 p12 密码
   - （可选）`APP_PROV_PROFILE_BASE64`

如何在本地验证解码后的文件正确性

```bash
# 将单行 base64 解码回 p12 文件
cat signcert.p12.base64.txt | base64 --decode > /tmp/signcert_restored.p12
# macOS 上有时用 -D 选项
# cat signcert.p12.base64.txt | base64 -D > /tmp/signcert_restored.p12

# 比较 SHA256（与原始文件一致）
shasum -a 256 path/to/signcert.p12
shasum -a 256 /tmp/signcert_restored.p12

# 查看 p12 内容（需 p12 密码）
openssl pkcs12 -in /tmp/signcert_restored.p12 -nokeys -passin pass:你的_p12_密码 -clcerts -info
```

触发 CI 并创建 Release（在仓库设置 Secrets 后）

```bash
# 创建并推送 tag（例如 v1.0.0），触发 workflow，若成功并生成 DMG，会自动创建 Release 并附加 DMG
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

清理建议（操作完成后）

```bash
# 删除临时生成的 base64 文件
rm -f signcert.p12.base64.txt profile.mobileprovision.base64.txt
rm -rf ./secrets-out
```

故障排查（常见问题）
- 如果 GH workflow 在创建 Release 或上传资产时报错：
  - 确认该 run 是由 tag 触发（`github.ref`），并且 `Detect generated DMG` 步骤显示 DMG 路径。
  - 确认 `permissions: contents: write` 在 workflow 中已设置（本仓库已设置）。
  - 检查 Actions 日志中 `Create GitHub Release for tag` 与 `Upload DMG to GitHub Release` 步骤的错误输出。

- 如果 codesign 失败：
  - 检查上传的 `.p12` 是否包含私钥以及 `APP_CERT_P12_PASSWORD` 是否正确。
  - 在本地用 openssl 解码并验证证书、私钥内容。

备注
- 我们在 workflow 中使用临时 keychain 导入 p12（并在 job 末尾删除）以避免在 runner 上长期留存证书。
- 若需自动 notarize（苹果公证），需额外提供 App Store Connect API key，并在 workflow 中添加 notarize 步骤。

如需我把上述说明也写进仓库根目录的 README 或创建 `scripts/README-secrets.md` 的不同位置/格式，请回复我会替你改写并提交。