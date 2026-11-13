# Protocol & Capability Foundation (Phase 2A)

This document outlines the Phase 2A structural foundations introduced to enable future Mesh capabilities (Chunking, Resume, Storage Abstraction) while maintaining 100% backward compatibility with Mesh 1.8.0.

## 1. Protocol Architecture
- **Protocol v2**: The current (1.8.x) HTTP/TCP contiguous stream protocol. Handled via /api/mesh/v2/.
- **Protocol v3 (Foundation)**: A future-proof structure where capability lists dictate transfer modes. Represented conceptually via dto_v3.rs without modifying active v2 endpoints.

## 2. Capability Model
Protocol capabilities are strictly decoupled from the Protocol Version.
**Supported Capability Claims:**
- tomic_commit: Renames .mesh.part to final file on success.
- sha256: Complete file streaming hash verification.
- chunk_transfer: Divides file into HTTP Range / bounded segments (Future).
- persistent_resume: Re-establishes broken chunk state across OS restarts (Future).

## 3. Negotiation Flow
1. **Discovery / Connect**: Peer A announces protocols (e.g. [V2_2, V3_0]) and Capabilities.
2. **Intersection**: Peer B intersects capabilities. Highest shared protocol wins (downgrade to V2_2 if V3 unsupported).
3. **Mode Assignment**: If V3_0 and chunk_transfer are negotiated, mode is ChunkedV3. Otherwise, it falls back to LegacyV2.

## 4. State Machine & Errors
**Transfer State Machine:**
Idle -> Negotiating -> Ready -> Transferring -> Verifying -> Committing -> Completed
(Failure edges: Cancelled, Failed, Rejected, Unsupported, Expired)

**Structured Domain Errors:**
No raw std::io::Error crosses the Dart bridge. All errors are mapped into domain concepts (e.g. IntegrityFailure, UnsupportedCapability).

## 5. Transport Boundary Preparation
Currently, the transfer engine (packages/core/src/http/server/v2.rs) is tightly coupled to hyper::Request<Incoming>.
**Future Boundary (TransportStream):**
`
ust
pub trait TransportStream {
    async fn read_chunk(&mut self) -> Result<Option<Bytes>, TransportError>;
}
`
The HTTP server will implement this trait, wrapping 
eq.into_body(). Future transports (WebRTC, QUIC) will provide their own trait implementations, shielding the core Transfer Engine.

## 6. Storage Boundary Preparation
Currently, dart's prepareFileSaveTarget handles Windows/Linux file paths + Android SAF ileDescriptors. 
**Future Boundary (StorageProvider):**
`
ust
pub trait StorageProvider {
    async fn prepare_save_target(&self, filename: &str) -> Result<FileSaveTarget, StorageError>;
    async fn commit_save_target(&self, target: &FileSaveTarget) -> Result<(), StorageError>;
}
`
This abstracts the file system completely away from the transfer engine.
