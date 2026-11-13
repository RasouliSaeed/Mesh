use serde::{Deserialize, Serialize};
use std::collections::HashSet;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Hash, PartialOrd, Ord)]
pub enum ProtocolVersion {
    #[serde(rename = "2.0")]
    V2_0,
    #[serde(rename = "2.2")]
    V2_2,
    #[serde(rename = "3.0")]
    V3_0,
}

impl Default for ProtocolVersion {
    fn default() -> Self {
        ProtocolVersion::V2_2
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Hash)]
#[serde(rename_all = "snake_case")]
pub enum Capability {
    AtomicCommit,
    Sha256,
    ChunkTransfer,
    PersistentResume,
    Compression,
    Messaging,
    SharedFolders,
    Clipboard,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TransferMode {
    LegacyV2,
    ChunkedV3,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TransferState {
    Idle,
    Negotiating,
    Ready,
    Transferring,
    Verifying,
    Committing,
    Completed,
    Cancelled,
    Failed,
    Rejected,
    Unsupported,
    Expired,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum ProtocolError {
    UnsupportedProtocol,
    UnsupportedCapability,
    InvalidHandshake,
    InvalidTransferRequest,
    InvalidFileMetadata,
    IntegrityFailure,
    ResumeUnsupported,
    TransferCancelled,
    TransferExpired,
    InternalError,
}

#[derive(Debug, Clone)]
pub struct NegotiatedSession {
    pub protocol: ProtocolVersion,
    pub capabilities: HashSet<Capability>,
    pub mode: TransferMode,
}

pub fn negotiate(
    our_protocols: &[ProtocolVersion],
    our_capabilities: &HashSet<Capability>,
    peer_protocols: &[ProtocolVersion],
    peer_capabilities: &HashSet<Capability>,
) -> Result<NegotiatedSession, ProtocolError> {
    // Find the highest mutually supported protocol
    let mut best_proto = None;
    let mut highest = ProtocolVersion::V2_0;

    for p in peer_protocols {
        if our_protocols.contains(p) {
            if best_proto.is_none() || *p >= highest {
                highest = *p;
                best_proto = Some(*p);
            }
        }
    }

    let protocol = best_proto.ok_or(ProtocolError::UnsupportedProtocol)?;

    // Intersect capabilities
    let mut capabilities = HashSet::new();
    for cap in peer_capabilities {
        if our_capabilities.contains(cap) {
            capabilities.insert(*cap);
        }
    }

    // Determine TransferMode
    let mode = if protocol == ProtocolVersion::V3_0 && capabilities.contains(&Capability::ChunkTransfer) {
        TransferMode::ChunkedV3
    } else {
        TransferMode::LegacyV2
    };

    Ok(NegotiatedSession {
        protocol,
        capabilities,
        mode,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_negotiation_v3_to_v3() {
        let our_protocols = vec![ProtocolVersion::V2_2, ProtocolVersion::V3_0];
        let our_caps = HashSet::from([Capability::Sha256, Capability::ChunkTransfer]);

        let peer_protocols = vec![ProtocolVersion::V2_2, ProtocolVersion::V3_0];
        let peer_caps = HashSet::from([Capability::Sha256, Capability::ChunkTransfer, Capability::PersistentResume]);

        let session = negotiate(&our_protocols, &our_caps, &peer_protocols, &peer_caps).unwrap();
        
        assert_eq!(session.protocol, ProtocolVersion::V3_0);
        assert_eq!(session.mode, TransferMode::ChunkedV3);
        assert!(session.capabilities.contains(&Capability::Sha256));
        assert!(session.capabilities.contains(&Capability::ChunkTransfer));
        assert!(!session.capabilities.contains(&Capability::PersistentResume));
    }

    #[test]
    fn test_negotiation_v3_to_v2() {
        let our_protocols = vec![ProtocolVersion::V2_2, ProtocolVersion::V3_0];
        let our_caps = HashSet::from([Capability::Sha256, Capability::ChunkTransfer]);

        let peer_protocols = vec![ProtocolVersion::V2_2];
        let peer_caps = HashSet::new();

        let session = negotiate(&our_protocols, &our_caps, &peer_protocols, &peer_caps).unwrap();
        
        assert_eq!(session.protocol, ProtocolVersion::V2_2);
        assert_eq!(session.mode, TransferMode::LegacyV2);
        assert!(session.capabilities.is_empty());
    }

    #[test]
    fn test_negotiation_v2_to_v3() {
        let our_protocols = vec![ProtocolVersion::V2_2];
        let our_caps = HashSet::new();

        let peer_protocols = vec![ProtocolVersion::V2_2, ProtocolVersion::V3_0];
        let peer_caps = HashSet::from([Capability::Sha256]);

        let session = negotiate(&our_protocols, &our_caps, &peer_protocols, &peer_caps).unwrap();
        
        assert_eq!(session.protocol, ProtocolVersion::V2_2);
        assert_eq!(session.mode, TransferMode::LegacyV2);
        assert!(session.capabilities.is_empty());
    }
}
