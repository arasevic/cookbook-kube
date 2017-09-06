module KubernetesCookbook
  # Resource to manage a scheduler
  class KubeScheduler < Chef::Resource
    resource_name :kube_scheduler

    property :version, String, default: '1.7.5'
    property :remote, String,
      default: lazy { |r|
        'https://storage.googleapis.com/kubernetes-release' \
        "/release/v#{r.version}/bin/linux/amd64/kube-scheduler"
      }
    property :checksum, String,
      default: '0c8b2b1710dad44284d3c8d39a518e5a0dcd549ad4f22edb8adfd5a0c93481ef'
    property :run_user, String, default: 'kubernetes'
    property :file_ulimit, Integer, default: 65536

    default_action :create

    action :create do
      remote_file 'kube-scheduler binary' do
        path scheduler_path
        mode '0755'
        source new_resource.remote
        checksum new_resource.checksum
      end
    end

    action :start do
      user 'kubernetes' do
        action :create
        only_if { new_resource.run_user == 'kubernetes' }
      end

      systemd_contents = {
        Unit: {
          Description: 'kube-scheduler',
          Documentation: 'https://k8s.io',
          After: 'network.target',
        },
        Service: {
          User: new_resource.run_user,
          ExecStart: generator.generate,
          Restart: 'on-failure',
          LimitNOFILE: new_resource.file_ulimit,
        },
        Install: {
          WantedBy: 'multi-user.target',
        },
      }

      systemd_unit 'kube-scheduler.service' do
        content(systemd_contents)
        action :create
        notifies :restart, 'service[kube-scheduler]', :immediately
      end

      service 'kube-scheduler' do
        action %w(enable start)
      end
    end

    def generator
      CommandGenerator.new(scheduler_path, self)
    end

    def scheduler_path
      '/usr/sbin/kube-scheduler'
    end
  end

  # scheduler commandline flags
  # Reference: http://kubernetes.io/docs/admin/kube-scheduler/
  class KubeScheduler
    property :address, default: '0.0.0.0'
    property :algorithm_provider, default: 'DefaultProvider'
    property :bind_pods_burst, default: 100
    property :bind_pods_qps, default: 50
    property :failure_domains, default: 'kubernetes.io/hostname,failure-domain.beta.kubernetes.io/zone,failure-domain.beta.kubernetes.io/region'
    property :feature_gates
    property :google_json_key
    property :hard_pod_affinity_symmetric_weight, default: 1
    property :kube_api_burst, default: 100
    property :kube_api_content_type, default: 'application/vnd.kubernetes.protobuf'
    property :kube_api_qps, default: 50
    property :kubeconfig
    property :leader_elect, default: true
    property :leader_elect_lease_duration, default: '15s'
    property :leader_elect_renew_deadline, default: '10s'
    property :leader_elect_retry_period, default: '2s'
    property :log_flush_frequency, default: '5s'
    property :master
    property :policy_config_file
    property :port, default: 10_251
    property :profiling, default: true
    property :scheduler_name, default: 'default-scheduler'

    property :v, default: 0
  end
end
