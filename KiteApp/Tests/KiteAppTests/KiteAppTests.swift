import Testing
@testable import KiteApp

// MARK: – String extension tests

@Suite("String extensions")
struct StringExtensionTests {

    @Test("relativeTimeAgo returns seconds")
    func relativeTimeAgoSeconds() {
        let now = ISO8601DateFormatter().string(from: Date(timeIntervalSinceNow: -30))
        #expect(now.relativeTimeAgo.hasSuffix("s"))
    }

    @Test("relativeTimeAgo returns minutes")
    func relativeTimeAgoMinutes() {
        let t = ISO8601DateFormatter().string(from: Date(timeIntervalSinceNow: -120))
        #expect(t.relativeTimeAgo.hasSuffix("m"))
    }

    @Test("k8sQuantityToDouble parses milli-CPU")
    func milliCPU() {
        #expect("500m".k8sQuantityToDouble == 0.5)
    }

    @Test("k8sQuantityToDouble parses MiB memory")
    func mibMemory() {
        #expect("128Mi".k8sQuantityToDouble == 128 * 1_048_576)
    }

    @Test("k8sQuantityToDouble parses GiB")
    func gibMemory() {
        #expect("1Gi".k8sQuantityToDouble == 1_073_741_824)
    }

    @Test("k8sQuantityToDouble parses nanocores")
    func nanocores() {
        #expect("1000000000n".k8sQuantityToDouble == 1.0)
    }
}

// MARK: – Model decoding tests

@Suite("Model decoding")
struct ModelDecodingTests {

    @Test("Cluster decodes from JSON")
    func clusterDecoding() throws {
        let json = """
        {
          "id": 1,
          "name": "test",
          "enabled": true,
          "inCluster": false,
          "isDefault": true,
          "createdAt": "2026-01-01T00:00:00Z",
          "updatedAt": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        let cluster = try JSONDecoder.k8s.decode(Cluster.self, from: json)
        #expect(cluster.id == 1)
        #expect(cluster.name == "test")
        #expect(cluster.enabled == true)
    }

    @Test("Pod decodes from minimal JSON")
    func podDecoding() throws {
        let json = """
        {
          "metadata": { "name": "my-pod", "namespace": "default" },
          "status": { "phase": "Running" }
        }
        """.data(using: .utf8)!
        let pod = try JSONDecoder.k8s.decode(Pod.self, from: json)
        #expect(pod.metadata.name == "my-pod")
        #expect(pod.status?.phase == "Running")
    }

    @Test("GenericResourceItem decodes from minimal JSON")
    func genericItemDecoding() throws {
        let json = """
        { "metadata": { "name": "foo", "namespace": "bar" } }
        """.data(using: .utf8)!
        let item = try JSONDecoder.k8s.decode(GenericResourceItem.self, from: json)
        #expect(item.name == "foo")
        #expect(item.namespace == "bar")
    }

    @Test("ResourceKind provides correct systemImage")
    func resourceKindImages() {
        #expect(!ResourceKind.pods.systemImage.isEmpty)
        #expect(!ResourceKind.nodes.systemImage.isEmpty)
        #expect(!ResourceKind.crds.systemImage.isEmpty)
    }

    @Test("ResourceKind isClusterScoped is correct")
    func clusterScopedKinds() {
        #expect(ResourceKind.nodes.isClusterScoped)
        #expect(ResourceKind.namespaces.isClusterScoped)
        #expect(!ResourceKind.pods.isClusterScoped)
        #expect(!ResourceKind.deployments.isClusterScoped)
    }
}
