use futures_util::Stream;
use std::pin::Pin;
use bytes::Bytes;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum TransportError {
    ConnectionFailed,
    ConnectionClosed,
    Timeout,
    ReadFailed,
    WriteFailed,
    Cancelled,
    ProtocolViolation,
    ResourceUnavailable,
    Unknown,
}

impl std::fmt::Display for TransportError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}

impl std::error::Error for TransportError {}

pub trait TransportStream: Stream<Item = Result<Bytes, TransportError>> + Send + Sync + Unpin {}

impl<T> TransportStream for T where T: Stream<Item = Result<Bytes, TransportError>> + Send + Sync + Unpin {}

pub type BoxedTransportStream = Pin<Box<dyn TransportStream>>;

/// Abstract peer address to decouple from raw SocketAddr
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PeerAddress {
    IPv4(String, u16),
    IPv6(String, u16),
    IPv6LinkLocal(String, u16, u32), // address, port, scope_id
    Other(String), // WebRTC, Wi-Fi Direct, etc.
}

#[allow(async_fn_in_trait)]
pub trait Transport: Send + Sync {
    /// Connect to a peer
    async fn connect(&self, address: &PeerAddress) -> Result<(), TransportError>;
    
    /// Disconnect from a peer
    async fn disconnect(&self, address: &PeerAddress) -> Result<(), TransportError>;
    
    /// Open a new stream (e.g., for transferring a file)
    async fn open_stream(&self, address: &PeerAddress) -> Result<BoxedTransportStream, TransportError>;
}
use crate::model::transfer::FileContent;
use tokio_util::sync::CancellationToken;

#[allow(async_fn_in_trait)]
pub trait TransportClient: Send + Sync {
    async fn upload(
        &self,
        address: &PeerAddress,
        session_id: &str,
        file_id: &str,
        content: FileContent,
        progress: Box<dyn Fn(u64) + Send + 'static>,
        cancel: CancellationToken,
    ) -> Result<(), TransportError>;
}
