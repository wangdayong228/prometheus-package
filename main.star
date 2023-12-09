CONFIG_DIR = "/config"
CONFIG_FILENAME = "prometheus-config.yml"
DEFAULT_SCRAPE_INTERVAL = "15s"

def run(plan, service_metrics_configs=[]):
    """ Starts a Prometheus server that scrapes metrics off the provided services prometheus metrics configurations.

    Args:
        service_metrics_info(list[dict[string, string]]): A list of prometheus metrics configs to scrape metrics from. 
           More info on scrape config here: https://prometheus.io/docs/prometheus/latest/configuration/configuration/#scrape_config
           eg.
           ```
           service_metrics_configs: [
                {
                    # services name or metrics job name
                    Name: "" , 

                    # endpoint to scrape metrics from, <services ip address>:<exposed metrics port>
                    Endpoint: "", 

                    # labels to associate with services metrics (eg. { "service_type": "api" } )
                    Labels:{}, 

                    # http path to scrape metrics from (defaults to "/metrics")
                    MetricsPath: "", 

                    # how frequently to scrape targets from this job (defaults to DEFAULT_SCRAPE_INTERVAL)
                    ScrapeInterval: ""
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