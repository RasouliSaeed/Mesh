with open('packages/mesh_isolates/rust/src/api/server.rs', 'r', encoding='utf-8') as f:
    content = f.read()

import re

# resolve_upload_target now needs to be async, but wait, it is called from respond_file_upload which is an async block!
# Let's check how it's called.
# let target = resolve_upload_target(path, file_descriptor, result_tx, progress_tx)?;
# We can change it to:
# let target = resolve_upload_target(path, file_descriptor, result_tx, progress_tx).await?;

content = content.replace(
    'let target = resolve_upload_target(path, file_descriptor, result_tx, progress_tx)?;\n',
    'let target = resolve_upload_target(path, file_descriptor, result_tx, progress_tx).await?;\n'
)

resolve_old = """fn resolve_upload_target(
    path: Option<String>,
    file_descriptor: Option<i32>,
    result_tx: oneshot::Sender<Result<(), String>>,
    progress_tx: mpsc::Sender<u64>,
) -> anyhow::Result<FileUploadTarget> {
    match (path, file_descriptor) {
        (Some(path), None) => Ok(FileUploadTarget::Path {
            path: path.into(),
            result_tx,
            progress_tx: Some(progress_tx),
        }),
        (None, Some(file_descriptor)) => {
            #[cfg(target_os = "android")]
            {
                Ok(FileUploadTarget::Fd {
                    fd: file_descriptor,
                    result_tx,
                    progress_tx: Some(progress_tx),
                })
            }
            #[cfg(not(target_os = "android"))]
            {
                let _ = (file_descriptor, result_tx, progress_tx);
                Err(anyhow::anyhow!(
                    "File descriptors are only supported on Android"
                ))
            }
        }
        _ => Err(anyhow::anyhow!(
            "Exactly one upload target must be provided"
        )),
    }
}"""

resolve_new = """async fn resolve_upload_target(
    path: Option<String>,
    file_descriptor: Option<i32>,
    result_tx: oneshot::Sender<Result<(), String>>,
    progress_tx: mpsc::Sender<u64>,
) -> anyhow::Result<FileUploadTarget> {
    match (path, file_descriptor) {
        (Some(path), None) => {
            let handle = mesh::model::storage_adapter::DesktopStorageHandle::new(path.into())
                .await
                .map_err(|e| anyhow::anyhow!("Failed to open storage: {e}"))?;
            Ok(FileUploadTarget::Storage {
                handle: Box::new(handle),
                result_tx,
                progress_tx: Some(progress_tx),
            })
        }
        (None, Some(file_descriptor)) => {
            #[cfg(target_os = "android")]
            {
                let handle = mesh::model::storage_adapter::AndroidSafStorageHandle::new(file_descriptor)
                    .await
                    .map_err(|e| anyhow::anyhow!("Failed to open SAF storage: {e}"))?;
                Ok(FileUploadTarget::Storage {
                    handle: Box::new(handle),
                    result_tx,
                    progress_tx: Some(progress_tx),
                })
            }
            #[cfg(not(target_os = "android"))]
            {
                let _ = (file_descriptor, result_tx, progress_tx);
                Err(anyhow::anyhow!(
                    "File descriptors are only supported on Android"
                ))
            }
        }
        _ => Err(anyhow::anyhow!(
            "Exactly one upload target must be provided"
        )),
    }
}"""

content = content.replace(resolve_old, resolve_new)

with open('packages/mesh_isolates/rust/src/api/server.rs', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated server.rs")
