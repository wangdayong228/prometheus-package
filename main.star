CONFIG_DIR = "/config"
CONFIG_FILENAME = "prometheus-config.yml"

def run(plan, service_metrics_info=[]):
    """ Starts a Prometheus server that scrapes metrics off the provided services/metrics job configurations.

    Args:
        service_metrics_info(list[dict[string, string]]): A list of 
           eg.
           ```
           service_metrics_configs: [
                {
                    Name:(make this service name) , 
                    Endpoint: (private ip address combined with the metrics port) , 
                    Labels={}, 
                    MetricsPath: (default: "/metrics"), 
                    ScrapeInterval: (provide a default) 
                },
                { 
                    ...
                },
            ]
           ```
    Returns:
        prometheus_url : endpoint to prometheus service inside the enclave (eg. 123.123.212:9090)
    """
    prometheus_config_template = read_file(src="./static-files/prometheus.yml.tmpl")

    prometheus_config_data = {
        "MetricsJobs": get_metrics_jobs(service_metrics_configs)
    }

    prom_config_files_artifact = plan.render_templates(
        config = {
            CONFIG_FILENAME: struct(
                template=prometheus_config_template,
                data=prometheus_config_data,
            )
        },
        name="prometheus-config",
    )

    config_file_path= CONFIG_DIR + "/" + CONFIG_FILENAME

    prometheus_service = plan.add_service(name="prometheus", config=ServiceConfig(
        image="prom/prometheus:latest",
        ports={
            "http": PortSpec(
                number=9090,
                transport_protocol="TCP",
                application_protocol="http",
            )
        },
        files={
            CONFIG_DIR:prom_config_files_artifact,
        },
        cmd=[
            "--config.file=" + config_file_path,
            "--storage.tsdb.path=/prometheus",
            "--storage.tsdb.retention.time=1d",
            "--storage.tsdb.retention.size=512MB",
            "--storage.tsdb.wal-compression",
            "--web.console.libraries=/etc/prometheus/console_libraries",
            "--web.console.templates=/etc/prometheus/consoles",
            "--web.enable-lifecycle",
        ]
    ))

    prometheus_service_ip_address = prometheus_service.ip_address
    prometheus_service_http_port = prometheus_service.ports["http"].number

    return "http://{0}:{1}".format(prometheus_service_ip_address, prometheus_service_http_port)
    
def get_metrics_jobs(service_metrics_configs):
    metrics_jobs = []
    return metrics_jobs