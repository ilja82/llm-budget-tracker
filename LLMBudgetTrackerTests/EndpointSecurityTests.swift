import XCTest

final class EndpointSecurityTests: XCTestCase {
    func testNormalizesSchemeHostWhitespaceAndTrailingSlashes() throws {
        XCTAssertEqual(
            try EndpointSecurity.normalizedBaseURLString(from: " \nHTTPS://PROXY.EXAMPLE.COM:8443/litellm///\n"),
            "https://proxy.example.com:8443/litellm"
        )
    }

    func testRootURLHasNoTrailingSlash() throws {
        XCTAssertEqual(
            try EndpointSecurity.normalizedBaseURLString(from: "https://proxy.example.com///"),
            "https://proxy.example.com"
        )
    }

    func testHTTPIsAllowedForLocalhostAndIPv4Loopback() throws {
        for host in ["localhost", "LOCALHOST", "127.0.0.1"] {
            let url = try EndpointSecurity.normalizedBaseURL(from: "http://\(host):4000/proxy/")
            XCTAssertEqual(url.scheme, "http")
            XCTAssertEqual(url.host, host.lowercased())
            XCTAssertEqual(url.port, 4000)
            XCTAssertEqual(url.path, "/proxy")
        }
    }

    func testHTTPIsAllowedForIPv6Loopback() throws {
        XCTAssertEqual(
            try EndpointSecurity.normalizedBaseURLString(from: "http://[::1]:4000/proxy/"),
            "http://[::1]:4000/proxy"
        )
    }

    func testHTTPRejectsRemoteAndLookalikeLoopbackHosts() {
        for host in ["proxy.example.com", "192.168.1.1", "localhost.example.com", "127.0.0.1.example.com"] {
            XCTAssertThrowsError(try EndpointSecurity.normalizedBaseURL(from: "http://\(host)")) { error in
                guard case EndpointSecurityError.insecureRemoteURL = error else {
                    return XCTFail("Unexpected error for \(host): \(error)")
                }
            }
        }
    }

    func testRejectsCredentialsQueryFragmentsAndInvalidSchemes() {
        let invalidURLs = [
            "", " \n", "not-a-url", "ftp://proxy.example.com", "https:///",
            "https://user:password@proxy.example.com", "https://user@proxy.example.com",
            "https://proxy.example.com?api_key=secret", "https://proxy.example.com#fragment"
        ]
        for url in invalidURLs {
            XCTAssertThrowsError(try EndpointSecurity.normalizedBaseURL(from: url), url) { error in
                guard case EndpointSecurityError.invalidURL = error else {
                    return XCTFail("Unexpected error for \(url): \(error)")
                }
            }
        }
    }
}
