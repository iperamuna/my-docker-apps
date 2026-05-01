#!/bin/bash
# Helper to create a GlitchTip superuser
docker exec -it glitchtip-web-1 ./manage.py createsuperuser
