use crate::model::transport::TransportError;
use bytes::Bytes;
use futures_util::Stream;
use hyper::body::{Body, Incoming};
use std::pin::Pin;
use std::task::{Context, Poll};

/// Wraps an HTTP Incoming body into a transport-independent stream of chunks.
pub struct HttpIncomingAdapter {
    body: Incoming,
}

impl HttpIncomingAdapter {
    pub fn new(body: Incoming) -> Self {
        Self { body }
    }
}

impl Stream for HttpIncomingAdapter {
    type Item = Result<Bytes, TransportError>;

    fn poll_next(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Option<Self::Item>> {
        match Pin::new(&mut self.body).poll_frame(cx) {
            Poll::Ready(Some(Ok(frame))) => {
                if let Ok(data) = frame.into_data() {
                    Poll::Ready(Some(Ok(data)))
                } else {
                    // Ignore non-data frames (trailers, etc.)
                    // In a more complex implementation we might loop, but returning
                    // a zero-sized chunk or continuing is standard. Here we return empty.
                    Poll::Ready(Some(Ok(Bytes::new())))
                }
            }
            Poll::Ready(Some(Err(_e))) => {
                Poll::Ready(Some(Err(TransportError::ReadFailed)))
            }
            Poll::Ready(None) => Poll::Ready(None),
            Poll::Pending => Poll::Pending,
        }
    }
}
