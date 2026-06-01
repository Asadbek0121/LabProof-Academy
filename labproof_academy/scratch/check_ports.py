import socket

ports_to_check = [8080, 8081, 8082, 3000, 3001, 5000, 5001, 8000, 8085, 9000, 9090]
for port in ports_to_check:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(0.5)
        result = s.connect_ex(('127.0.0.1', port))
        if result == 0:
            print(f"Port {port} is OPEN")
        else:
            pass
