# Storage & Persistence on RunPod

Your Pod has multiple storage layers with different lifecycles:

- Container disk (containerDiskInGb)
  - Volatile. Wiped when the Pod restarts or moves.
  - Good for OS/packages only.
- Pod volume (volumeInGb)
  - Persists across restarts, but is deleted when the Pod is deleted.
  - Good for temporary models/data while a Pod exists.
- Network volume
  - Persists independently of Pods and can be attached to future Pods.
  - Recommended for keeping models/data between terminated Pods.

## Recommendations
- Use a Network Volume to store models and any data you want to outlive Pods.
- Mount it at `/workspace` (or your preferred path) consistently across Pods.
- Keep secrets out of images; use RunPod Secrets where possible.

## How to attach a Network Volume
1. Create a Network Volume in RunPod console (choose size and data center)
2. Note the `networkVolumeId`
3. In provisioning, attach it and set a mount path

### With the provided script
- If you pass `-NetworkVolumeId`, the script will attach it and skip `volumeInGb`.
- Example:

```powershell
pwsh -File .\scripts\runpod-create-pod.ps1 -RunpodApiKey '<RUNPOD_API_KEY>' `
  -Preset vllm-openai -Name 'legal-vllm' -GpuQuery 'H100' -GpuCount 1 `
  -NetworkVolumeId 'agv6w2qcg7' -VolumeMountPath '/workspace'
```

## Data layout
- `/workspace/models` — models and weights
- `/workspace/data` — your uploaded corpora or intermediate outputs
- `/workspace/logs` — logs/metrics

## Migration
- You can delete a Pod and re-create a new one, attaching the same Network Volume to preserve data.

## Backups
- Periodically snapshot or sync the Network Volume contents to cloud storage (S3/R2) for disaster recovery.
