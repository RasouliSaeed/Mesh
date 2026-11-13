use crate::model::discovery::DeviceType;
use crate::model::discovery::device_type_v2;
use crate::model::protocol::{Capability, ProtocolVersion};
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RegisterDtoV3 {
    pub alias: String,
    
    /// Must contain "3.0" for this DTO.
    pub version: String,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    pub device_model: Option<String>,
    
    #[serde(default, with = "device_type_v2", skip_serializing_if = "Option::is_none")]
    pub device_type: Option<DeviceType>,
    
    pub fingerprint: String,
    pub port: u16,
    pub protocol: String,
    pub download: bool,
    
    /// Protocols this peer supports (e.g., [V2_2, V3_0])
    pub supported_protocols: Vec<ProtocolVersion>,
    
    /// Capabilities this peer supports
    pub capabilities: HashSet<Capability>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PrepareUploadRequestDtoV3 {
    pub info: RegisterDtoV3,
    pub files: HashMap<String, FileDtoV3>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PrepareUploadResponseDtoV3 {
    pub session_id: String,
    pub files: HashMap<String, String>, // token map
    pub negotiated_capabilities: HashSet<Capability>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileDtoV3 {
    pub id: String,
    pub file_name: String,
    pub size: u64,
    pub file_type: String,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sha256: Option<String>,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    pub preview: Option<String>,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    pub metadata: Option<crate::model::transfer::FileMetadata>,
    
    // -- V3 Chunk/Resume extensions (Future Foundation) -- //
    
    #[serde(default)]
    pub chunk_transfer_supported: bool,
    
    #[serde(default)]
    pub persistent_resume_supported: bool,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    pub chunk_size: Option<u64>,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    pub chunk_count: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChunkDtoV3 {
    pub session_id: String,
    pub file_id: String,
    pub chunk_index: u64,
    pub offset: u64,
    pub size: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub chunk_hash: Option<String>,
}
