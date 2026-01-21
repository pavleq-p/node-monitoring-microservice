from prometheus_client import start_http_server, Counter, Gauge
import time
import os

HOST_TYPE = Gauge('host_type', 'Type of host the service is running on', ['type'])
HTTP_REQUESTS = Counter('http_requests_total', 'Total HTTP requests')
UPTIME = Gauge('uptime_seconds', 'Uptime of the service in seconds')
ERRORS = Counter('errors_total', 'Total errors occurred')

def detect_host_type():
    if os.path.exists('/.dockerenv'):
        return 'container'

    try:
        with open('/proc/self/cgroup', 'r') as f:
            cgroup_content = f.read()
        if any(x in cgroup_content for x in ['docker', 'lxc', 'containerd', 'kubepod']):
            return 'container'
    except:
        pass

    try:
        with open('/sys/class/dmi/id/product_name', 'r') as f:
            product = f.read().strip().lower()
        if any(x in product for x in ['virtual', 'vmware', 'qemu', 'kvm', 'xen', 'hyperv']):
            return 'virtual_machine'
    except:
        pass

    return 'physical'

def main():
    host_type_override = os.environ.get('HOST_TYPE_OVERRIDE')
    if host_type_override:
        host_type = host_type_override
    else:
        host_type = detect_host_type()

    HOST_TYPE.labels(type=host_type).set(1)

    start_time = time.time()
    UPTIME.set_function(lambda: int(time.time() - start_time))

    print(f"Microservice started on http://localhost:8080")
    start_http_server(8080)

    counter = 0
    while True:
        HTTP_REQUESTS.inc()
        counter += 1
        if counter % 10 == 0:
            ERRORS.inc()
            print("Simulated error occurred!")
        time.sleep(1)

if __name__ == '__main__':
    main()