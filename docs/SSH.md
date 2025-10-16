# SSH access to RunPod pods (optional)

You can enable SSH (key-only) on vLLM pods for direct shell access.

## Generate an SSH key (Windows PowerShell)
```powershell
# Creates id_ed25519 (private) and id_ed25519.pub (public)
ssh-keygen -t ed25519 -C "runpod-access" -f $HOME\.ssh\id_ed25519
```

Tip: Or run the helper which sets RUNPOD_SSH_PUBKEY automatically:
```powershell
pwsh -File .\scripts\setup-ssh-env.ps1
```

## Provision a pod with SSH enabled
- Use the public key contents (id_ed25519.pub)
- Either set an env var or pass as a parameter

Environment variable method:
```powershell
$env:RUNPOD_SSH_PUBKEY = (Get-Content $HOME\.ssh\id_ed25519.pub -Raw)
```

Or pass directly:
```powershell
$pub = Get-Content $HOME\.ssh\id_ed25519.pub -Raw
pwsh -File .\scripts\runpod-create-pod.ps1 -Preset vllm-openai -Name 'legal-vllm' -GpuQuery 'H100' -GpuCount 1 `
  -VolumeInGb 100 -ContainerDiskInGb 50 -EnableSsh -SshPublicKey $pub
```

Notes:
- The script opens port `22/tcp`, installs `openssh-server`, writes your key to `/root/.ssh/authorized_keys`, disables password auth, and starts `sshd`.
- SSH is only wired for the `vllm-openai` preset.

## Connect to the pod
- In the RunPod console → Pod → Runtime → look for the public IP and mapped TCP port
- Example (replace PORT):
```powershell
ssh -i $HOME\.ssh\id_ed25519 root@<PUBLIC_IP> -p <PORT>
```

Security tips:
- Use key-only auth (no passwords). Never share private keys.
- Remove the pod or rotate keys if you suspect compromise.
