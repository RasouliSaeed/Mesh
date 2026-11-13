#![cfg(feature = "http")]

//! Tests for V3 registration contract, response deserialization,
//! TLS certificate validation, and V2 backward compatibility.

use locara::http::client::{ClientError, LsHttpClientV2, LsHttpClientV3};
use locara::http::dto::RegisterDto;
use locara::http::dto_v2::RegisterDtoV2;
use locara::http::server::web::WebConfig;
use locara::http::server::{start_with_port, ServerConfigV2, TlsConfig};
use locara::http::state::ClientInfo;
use locara::model::discovery::ProtocolType;
use tokio::sync::{mpsc, oneshot};

struct TestServer {
    port: u16,
    _stop_tx: oneshot::Sender<()>,
}

struct Identity {
    cert: String,
    private_key: String,
    fingerprint: String,
}

fn generate_identity() -> Identity {
    let cert = locara::crypto::cert::generate_self_signed().unwrap();
    Identity {
        cert: cert.certificate_pem,
        private_key: cert.private_key_pem,
        fingerprint: cert.fingerprint,
    }
}

async fn start_test_server(tls: Option<TlsConfig>, token: &str, enable_v2: bool) -> TestServer {
    let (stop_tx, stop_rx) = oneshot::channel();
    let (event_tx, _event_rx) = mpsc::channel(16);

    let v2_config = if enable_v2 {
        Some(ServerConfigV2 {
            pin: None,
            verify_checksums: false,
            event_tx,
        })
    } else {
        None
    };

    let handle = start_with_port(
        0,
        tls,
        ClientInfo {
            alias: "Test Server".to_string(),
            version: "3.0".to_string(),
            device_model: Some("Rust".to_string()),
            device_type: None,
            token: token.to_string(),
        },
        None,
        v2_config,
        WebConfig::default(),
        stop_rx,
    )
    .await
    .unwrap();

    TestServer {
        port: handle.port(),
        _stop_tx: stop_tx,
    }
}

fn v3_sender_info(token: &str, protocol: ProtocolType) -> RegisterDto {
    RegisterDto {
        alias: "Test Client V3".to_string(),
        version: "3.0".to_string(),
        device_model: Some("Rust".to_string()),
        device_type: None,
        token: token.to_string(),
        port: 53317,
        protocol,
        has_web_interface: false,
    }
}

fn v2_sender_info(fingerprint: &str, protocol: ProtocolType) -> RegisterDtoV2 {
    RegisterDtoV2 {
        alias: "Test Client V2".to_string(),
        version: "2.2".to_string(),
        device_model: Some("Rust".to_string()),
        device_type: None,
        fingerprint: fingerprint.to_string(),
        port: 53317,
        protocol,
        download: false,
    }
}

#[tokio::test]
async fn test_v3_register_accepts_v3_dto_and_returns_expected_response() {
    let server = start_test_server(None, "server-token-123", true).await;
    let client = LsHttpClientV3::try_new_without_cert().unwrap();

    let response = client
        .register(
            ProtocolType::Http,
            "127.0.0.1",
            server.port,
            v3_sender_info("client-token-456", ProtocolType::Http),
        )
        .await
        .expect("V3 registration over HTTP should succeed");

    assert_eq!(response.body.alias, "Test Server");
    assert_eq!(response.body.version, "3.0");
    assert_eq!(response.body.token, "server-token-123");
    assert!(!response.body.has_web_interface);
}

#[tokio::test]
async fn test_v3_register_over_tls_matching_cert() {
    let server_identity = generate_identity();
    let client_identity = generate_identity();

    let server = start_test_server(
        Some(TlsConfig {
            cert: server_identity.cert.clone(),
            private_key: server_identity.private_key.clone(),
        }),
        &server_identity.fingerprint,
        true,
    )
    .await;

    let client = LsHttpClientV3::try_new(
        &client_identity.private_key,
        &client_identity.cert,
        Some(server_identity.fingerprint.clone()),
        None,
    )
    .unwrap();

    let response = client
        .register(
            ProtocolType::Https,
            "127.0.0.1",
            server.port,
            v3_sender_info(&client_identity.fingerprint, ProtocolType::Https),
        )
        .await
        .expect("V3 registration with matching client certificate should succeed");

    assert!(response.public_key.is_some());
    assert_eq!(response.body.alias, "Test Server");
    assert_eq!(response.body.token, server_identity.fingerprint);
}

#[tokio::test]
async fn test_v3_register_over_tls_mismatched_cert_rejected() {
    let server_identity = generate_identity();
    let client_identity = generate_identity();

    let server = start_test_server(
        Some(TlsConfig {
            cert: server_identity.cert.clone(),
            private_key: server_identity.private_key.clone(),
        }),
        &server_identity.fingerprint,
        true,
    )
    .await;

    let client = LsHttpClientV3::try_new(
        &client_identity.private_key,
        &client_identity.cert,
        Some(server_identity.fingerprint.clone()),
        None,
    )
    .unwrap();

    // Send a mismatched token that does not equal client_identity.fingerprint
    let result = client
        .register(
            ProtocolType::Https,
            "127.0.0.1",
            server.port,
            v3_sender_info("WRONG_FINGERPRINT", ProtocolType::Https),
        )
        .await;

    assert!(
        result.is_err(),
        "V3 registration with mismatched client certificate fingerprint must be rejected"
    );
    match result {
        Err(ClientError::Reqwest(err)) => {
            if let Some(status) = err.status() {
                assert_eq!(status.as_u16(), 403);
            }
        }
        Err(ClientError::Other(err)) => {
            let msg = err.to_string();
            assert!(msg.contains("403") || msg.contains("Forbidden"));
        }
        _ => {}
    }
}

#[tokio::test]
async fn test_v2_register_remains_unchanged() {
    let server = start_test_server(None, "server-token-123", true).await;
    let client = LsHttpClientV2::try_new_without_cert().unwrap();

    let response = client
        .register(
            ProtocolType::Http,
            "127.0.0.1",
            server.port,
            v2_sender_info("client-fingerprint-456", ProtocolType::Http),
        )
        .await
        .expect("V2 registration should continue working unchanged");

    assert_eq!(response.body.alias, "Test Server");
    assert_eq!(response.body.version, "2.2");
    assert_eq!(response.body.fingerprint, "server-token-123");
    assert!(!response.body.download);
}
