File: services\customer-service\start.sh
````````sh
#!/bin/sh
exec uvicorn app.main:app --host 0.0.0.0 --port ${SERVICE_PORT}
