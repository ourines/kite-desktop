import Foundation

// MARK: – Shared Kubernetes metadata

struct ObjectMeta: Codable {
    var name: String
    var namespace: String?
    var uid: String?
    var resourceVersion: String?
    var creationTimestamp: String?
    var labels: [String: String]?
    var annotations: [String: String]?
    var ownerReferences: [OwnerReference]?
    var finalizers: [String]?
    var deletionTimestamp: String?
}

struct OwnerReference: Codable {
    var apiVersion: String
    var kind: String
    var name: String
    var uid: String
    var controller: Bool?
}

// MARK: – Generic list wrapper

struct K8sList<T: Codable>: Codable {
    var items: [T]
    var metadata: ListMeta?
}

struct ListMeta: Codable {
    var `continue`: String?
    var remainingItemCount: Int?
}

// MARK: – Pod

struct Pod: Codable, Identifiable {
    var metadata: ObjectMeta
    var spec: PodSpec?
    var status: PodStatus?
    var id: String { metadata.uid ?? metadata.name }
}

struct PodSpec: Codable {
    var nodeName: String?
    var containers: [Container]
    var initContainers: [Container]?
    var serviceAccountName: String?
    var restartPolicy: String?
}

struct Container: Codable, Identifiable {
    var name: String
    var image: String?
    var id: String { name }
    var resources: ResourceRequirements?
}

struct ResourceRequirements: Codable {
    var requests: [String: String]?
    var limits: [String: String]?
}

struct PodStatus: Codable {
    var phase: String?
    var conditions: [PodCondition]?
    var containerStatuses: [ContainerStatus]?
    var initContainerStatuses: [ContainerStatus]?
    var podIP: String?
    var hostIP: String?
    var startTime: String?
    var message: String?
    var reason: String?
}

struct PodCondition: Codable {
    var type: String
    var status: String
    var message: String?
    var reason: String?
}

struct ContainerStatus: Codable {
    var name: String
    var ready: Bool
    var restartCount: Int
    var image: String?
    var state: ContainerState?
    var lastState: ContainerState?
}

struct ContainerState: Codable {
    var running: ContainerStateRunning?
    var waiting: ContainerStateWaiting?
    var terminated: ContainerStateTerminated?
}

struct ContainerStateRunning: Codable {
    var startedAt: String?
}

struct ContainerStateWaiting: Codable {
    var reason: String?
    var message: String?
}

struct ContainerStateTerminated: Codable {
    var reason: String?
    var message: String?
    var exitCode: Int?
    var startedAt: String?
    var finishedAt: String?
}

// MARK: – Deployment

struct Deployment: Codable, Identifiable {
    var metadata: ObjectMeta
    var spec: DeploymentSpec?
    var status: DeploymentStatus?
    var id: String { metadata.uid ?? metadata.name }
}

struct DeploymentSpec: Codable {
    var replicas: Int?
    var selector: LabelSelector?
    var template: PodTemplateSpec?
    var strategy: DeploymentStrategy?
    var paused: Bool?
}

struct DeploymentStrategy: Codable {
    var type: String?
}

struct DeploymentStatus: Codable {
    var replicas: Int?
    var readyReplicas: Int?
    var availableReplicas: Int?
    var updatedReplicas: Int?
    var unavailableReplicas: Int?
    var observedGeneration: Int?
    var conditions: [DeploymentCondition]?
}

struct DeploymentCondition: Codable {
    var type: String
    var status: String
    var reason: String?
    var message: String?
}

struct PodTemplateSpec: Codable {
    var metadata: ObjectMeta?
    var spec: PodSpec?
}

struct LabelSelector: Codable {
    var matchLabels: [String: String]?
}

// MARK: – StatefulSet

struct StatefulSet: Codable, Identifiable {
    var metadata: ObjectMeta
    var spec: StatefulSetSpec?
    var status: StatefulSetStatus?
    var id: String { metadata.uid ?? metadata.name }
}

struct StatefulSetSpec: Codable {
    var replicas: Int?
    var selector: LabelSelector?
    var serviceName: String?
}

struct StatefulSetStatus: Codable {
    var replicas: Int
    var readyReplicas: Int?
    var currentReplicas: Int?
    var updatedReplicas: Int?
    var availableReplicas: Int?
}

// MARK: – DaemonSet

struct DaemonSet: Codable, Identifiable {
    var metadata: ObjectMeta
    var spec: DaemonSetSpec?
    var status: DaemonSetStatus?
    var id: String { metadata.uid ?? metadata.name }
}

struct DaemonSetSpec: Codable {
    var selector: LabelSelector?
}

struct DaemonSetStatus: Codable {
    var desiredNumberScheduled: Int
    var numberReady: Int
    var numberAvailable: Int?
    var numberUnavailable: Int?
    var updatedNumberScheduled: Int?
}

// MARK: – Job / CronJob

struct Job: Codable, Identifiable {
    var metadata: ObjectMeta
    var spec: JobSpec?
    var status: JobStatus?
    var id: String { metadata.uid ?? metadata.name }
}

struct JobSpec: Codable {
    var completions: Int?
    var parallelism: Int?
    var backoffLimit: Int?
}

struct JobStatus: Codable {
    var active: Int?
    var succeeded: Int?
    var failed: Int?
    var completionTime: String?
    var startTime: String?
    var conditions: [JobCondition]?
}

struct JobCondition: Codable {
    var type: String
    var status: String
    var reason: String?
    var message: String?
}

struct CronJob: Codable, Identifiable {
    var metadata: ObjectMeta
    var spec: CronJobSpec?
    var status: CronJobStatus?
    var id: String { metadata.uid ?? metadata.name }
}

struct CronJobSpec: Codable {
    var schedule: String?
    var suspend: Bool?
    var jobTemplate: JobTemplate?
}

struct JobTemplate: Codable {
    var spec: JobSpec?
}

struct CronJobStatus: Codable {
    var active: [ObjectReference]?
    var lastScheduleTime: String?
    var lastSuccessfulTime: String?
}

struct ObjectReference: Codable {
    var name: String?
    var namespace: String?
    var kind: String?
}

// MARK: – ReplicaSet

struct ReplicaSet: Codable, Identifiable {
    var metadata: ObjectMeta
    var spec: ReplicaSetSpec?
    var status: ReplicaSetStatus?
    var id: String { metadata.uid ?? metadata.name }
}

struct ReplicaSetSpec: Codable {
    var replicas: Int?
    var selector: LabelSelector?
}

struct ReplicaSetStatus: Codable {
    var replicas: Int
    var readyReplicas: Int?
    var availableReplicas: Int?
}

// MARK: – Service

struct Service: Codable, Identifiable {
    var metadata: ObjectMeta
    var spec: ServiceSpec?
    var status: ServiceStatus?
    var id: String { metadata.uid ?? metadata.name }
}

struct ServiceSpec: Codable {
    var type: String?
    var clusterIP: String?
    var clusterIPs: [String]?
    var externalIPs: [String]?
    var ports: [ServicePort]?
    var selector: [String: String]?
    var loadBalancerIP: String?
    var externalName: String?
}

struct ServicePort: Codable, Identifiable {
    var name: String?
    var port: Int
    var targetPort: TargetPort?
    var protocol: String?
    var nodePort: Int?
    var id: String { name ?? "\(port)" }
}

enum TargetPort: Codable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Int.self)    { self = .int(v);    return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        throw DecodingError.typeMismatch(TargetPort.self, .init(codingPath: decoder.codingPath, debugDescription: ""))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .int(let v):    try c.encode(v)
        case .string(let v): try c.encode(v)
        }
    }

    var displayString: String {
        switch self { case .int(let v): return "\(v)"; case .string(let v): return v }
    }
}

struct ServiceStatus: Codable {
    var loadBalancer: LoadBalancerStatus?
}

struct LoadBalancerStatus: Codable {
    var ingress: [LoadBalancerIngress]?
}

struct LoadBalancerIngress: Codable {
    var ip: String?
    var hostname: String?
}

// MARK: – Namespace

struct K8sNamespace: Codable, Identifiable {
    var metadata: ObjectMeta
    var spec: NamespaceSpec?
    var status: NamespaceStatus?
    var id: String { metadata.uid ?? metadata.name }
}

struct NamespaceSpec: Codable {
    var finalizers: [String]?
}

struct NamespaceStatus: Codable {
    var phase: String?
}

// MARK: – Node

struct Node: Codable, Identifiable {
    var metadata: ObjectMeta
    var spec: NodeSpec?
    var status: NodeStatus?
    var id: String { metadata.uid ?? metadata.name }
}

struct NodeSpec: Codable {
    var taints: [Taint]?
    var unschedulable: Bool?
    var podCIDR: String?
}

struct Taint: Codable, Identifiable {
    var key: String
    var value: String?
    var effect: String
    var id: String { "\(key)=\(value ?? ""):\(effect)" }
}

struct NodeStatus: Codable {
    var conditions: [NodeCondition]?
    var capacity: [String: String]?
    var allocatable: [String: String]?
    var addresses: [NodeAddress]?
    var nodeInfo: NodeSystemInfo?
}

struct NodeCondition: Codable {
    var type: String
    var status: String
    var reason: String?
    var message: String?
    var lastHeartbeatTime: String?
}

struct NodeAddress: Codable {
    var type: String
    var address: String
}

struct NodeSystemInfo: Codable {
    var osImage: String?
    var kernelVersion: String?
    var kubeletVersion: String?
    var containerRuntimeVersion: String?
    var architecture: String?
}

// MARK: – ConfigMap / Secret

struct ConfigMap: Codable, Identifiable {
    var metadata: ObjectMeta
    var data: [String: String]?
    var binaryData: [String: String]?
    var id: String { metadata.uid ?? metadata.name }
}

struct Secret: Codable, Identifiable {
    var metadata: ObjectMeta
    var type: String?
    var data: [String: String]?
    var stringData: [String: String]?
    var id: String { metadata.uid ?? metadata.name }
}

// MARK: – PersistentVolume / PersistentVolumeClaim

struct PersistentVolume: Codable, Identifiable {
    var metadata: ObjectMeta
    var spec: PVSpec?
    var status: PVStatus?
    var id: String { metadata.uid ?? metadata.name }
}

struct PVSpec: Codable {
    var capacity: [String: String]?
    var accessModes: [String]?
    var persistentVolumeReclaimPolicy: String?
    var storageClassName: String?
    var volumeMode: String?
    var claimRef: ObjectReference?
}

struct PVStatus: Codable {
    var phase: String?
    var reason: String?
    var message: String?
}

struct PersistentVolumeClaim: Codable, Identifiable {
    var metadata: ObjectMeta
    var spec: PVCSpec?
    var status: PVCStatus?
    var id: String { metadata.uid ?? metadata.name }
}

struct PVCSpec: Codable {
    var accessModes: [String]?
    var storageClassName: String?
    var volumeName: String?
    var resources: ResourceRequirements?
    var volumeMode: String?
}

struct PVCStatus: Codable {
    var phase: String?
    var capacity: [String: String]?
    var accessModes: [String]?
}

// MARK: – StorageClass

struct StorageClass: Codable, Identifiable {
    var metadata: ObjectMeta
    var provisioner: String?
    var reclaimPolicy: String?
    var volumeBindingMode: String?
    var allowVolumeExpansion: Bool?
    var id: String { metadata.uid ?? metadata.name }
}

// MARK: – Ingress

struct Ingress: Codable, Identifiable {
    var metadata: ObjectMeta
    var spec: IngressSpec?
    var status: IngressStatus?
    var id: String { metadata.uid ?? metadata.name }
}

struct IngressSpec: Codable {
    var ingressClassName: String?
    var rules: [IngressRule]?
    var tls: [IngressTLS]?
    var defaultBackend: IngressBackend?
}

struct IngressRule: Codable {
    var host: String?
    var http: HTTPIngressRuleValue?
}

struct HTTPIngressRuleValue: Codable {
    var paths: [HTTPIngressPath]?
}

struct HTTPIngressPath: Codable {
    var path: String?
    var pathType: String?
    var backend: IngressBackend?
}

struct IngressBackend: Codable {
    var service: IngressServiceBackend?
}

struct IngressServiceBackend: Codable {
    var name: String?
    var port: ServiceBackendPort?
}

struct ServiceBackendPort: Codable {
    var number: Int?
    var name: String?
}

struct IngressTLS: Codable {
    var hosts: [String]?
    var secretName: String?
}

struct IngressStatus: Codable {
    var loadBalancer: LoadBalancerStatus?
}

// MARK: – NetworkPolicy

struct NetworkPolicy: Codable, Identifiable {
    var metadata: ObjectMeta
    var spec: NetworkPolicySpec?
    var id: String { metadata.uid ?? metadata.name }
}

struct NetworkPolicySpec: Codable {
    var podSelector: LabelSelector?
    var policyTypes: [String]?
}

// MARK: – HorizontalPodAutoscaler

struct HPA: Codable, Identifiable {
    var metadata: ObjectMeta
    var spec: HPASpec?
    var status: HPAStatus?
    var id: String { metadata.uid ?? metadata.name }
}

struct HPASpec: Codable {
    var scaleTargetRef: CrossVersionObjectReference?
    var minReplicas: Int?
    var maxReplicas: Int
}

struct CrossVersionObjectReference: Codable {
    var kind: String
    var name: String
    var apiVersion: String?
}

struct HPAStatus: Codable {
    var currentReplicas: Int
    var desiredReplicas: Int
    var currentMetrics: [HPAMetricStatus]?
}

struct HPAMetricStatus: Codable {
    var type: String
}

// MARK: – RBAC

struct Role: Codable, Identifiable {
    var metadata: ObjectMeta
    var rules: [PolicyRule]?
    var id: String { metadata.uid ?? metadata.name }
}

struct ClusterRole: Codable, Identifiable {
    var metadata: ObjectMeta
    var rules: [PolicyRule]?
    var id: String { metadata.uid ?? metadata.name }
}

struct PolicyRule: Codable {
    var apiGroups: [String]?
    var resources: [String]?
    var verbs: [String]
}

struct RoleBinding: Codable, Identifiable {
    var metadata: ObjectMeta
    var subjects: [Subject]?
    var roleRef: RoleRef?
    var id: String { metadata.uid ?? metadata.name }
}

struct ClusterRoleBinding: Codable, Identifiable {
    var metadata: ObjectMeta
    var subjects: [Subject]?
    var roleRef: RoleRef?
    var id: String { metadata.uid ?? metadata.name }
}

struct Subject: Codable {
    var kind: String
    var name: String
    var namespace: String?
}

struct RoleRef: Codable {
    var kind: String
    var name: String
    var apiGroup: String
}

struct ServiceAccount: Codable, Identifiable {
    var metadata: ObjectMeta
    var secrets: [ObjectReference]?
    var id: String { metadata.uid ?? metadata.name }
}

// MARK: – Event

struct K8sEvent: Codable, Identifiable {
    var metadata: ObjectMeta
    var type: String?
    var reason: String?
    var message: String?
    var count: Int?
    var firstTime: String?
    var lastTime: String?
    var involvedObject: ObjectReference?
    var id: String { metadata.uid ?? metadata.name }
}

// MARK: – CRD / Custom Resource

struct CRD: Codable, Identifiable {
    var metadata: ObjectMeta
    var spec: CRDSpec?
    var id: String { metadata.uid ?? metadata.name }
}

struct CRDSpec: Codable {
    var group: String?
    var names: CRDNames?
    var scope: String?
    var versions: [CRDVersion]?
}

struct CRDNames: Codable {
    var plural: String?
    var singular: String?
    var kind: String?
}

struct CRDVersion: Codable {
    var name: String
    var served: Bool
    var storage: Bool
}

struct CustomResource: Codable, Identifiable {
    var apiVersion: String?
    var kind: String?
    var metadata: ObjectMeta
    var spec: AnyCodable?
    var status: AnyCodable?
    var id: String { metadata.uid ?? metadata.name }
}

// MARK: – AnyCodable helper

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self)             { value = v; return }
        if let v = try? c.decode(Int.self)              { value = v; return }
        if let v = try? c.decode(Double.self)           { value = v; return }
        if let v = try? c.decode(String.self)           { value = v; return }
        if let v = try? c.decode([String: AnyCodable].self) { value = v; return }
        if let v = try? c.decode([AnyCodable].self)     { value = v; return }
        value = ()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let v as Bool:                     try c.encode(v)
        case let v as Int:                      try c.encode(v)
        case let v as Double:                   try c.encode(v)
        case let v as String:                   try c.encode(v)
        case let v as [String: AnyCodable]:     try c.encode(v)
        case let v as [AnyCodable]:             try c.encode(v)
        default:                                try c.encodeNil()
        }
    }
}

// MARK: – Resource history

struct ResourceHistory: Codable, Identifiable {
    var id: Int
    var clusterName: String
    var resourceType: String
    var resourceName: String
    var namespace: String
    var operationType: String
    var operationSource: String
    var resourceYaml: String
    var previousYaml: String
    var success: Bool
    var errorMessage: String
    var createdAt: String
    var updatedAt: String
}

struct ResourceHistoryResponse: Codable {
    var data: [ResourceHistory]
    var pagination: PaginationInfo
}

struct PaginationInfo: Codable {
    var page: Int
    var pageSize: Int
    var total: Int
    var totalPages: Int
    var hasNextPage: Bool
    var hasPrevPage: Bool
}

// MARK: – Pod metrics

struct PodMetrics: Codable, Identifiable {
    struct ContainerMetrics: Codable {
        var name: String
        var usage: MetricsUsage
    }
    struct MetricsUsage: Codable {
        var cpu: String
        var memory: String
    }
    var metadata: ObjectMeta
    var containers: [ContainerMetrics]
    var id: String { metadata.uid ?? metadata.name }
}

struct PodMonitoringMetrics: Codable {
    var cpu: [UsageDataPoint]
    var memory: [UsageDataPoint]
    var networkIn: [UsageDataPoint]?
    var networkOut: [UsageDataPoint]?
    var fallback: Bool?
}

// MARK: – File info (pod file browser)

struct FileInfo: Codable, Identifiable {
    var name: String
    var isDir: Bool
    var size: String
    var modTime: String
    var mode: String
    var uid: String
    var gid: String
    var id: String { name }
}

// MARK: – Related resources

struct RelatedResource: Codable, Identifiable {
    var type: String
    var name: String
    var namespace: String?
    var apiVersion: String?
    var id: String { "\(type)/\(namespace ?? "")/\(name)" }
}

// MARK: – Gateway / HTTPRoute (simplified)

struct Gateway: Codable, Identifiable {
    var metadata: ObjectMeta
    var spec: AnyCodable?
    var status: AnyCodable?
    var id: String { metadata.uid ?? metadata.name }
}

struct HTTPRoute: Codable, Identifiable {
    var metadata: ObjectMeta
    var spec: AnyCodable?
    var status: AnyCodable?
    var id: String { metadata.uid ?? metadata.name }
}
