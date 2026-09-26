import os
from celery import Celery

# Set default Django settings module
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'saathi_shield.settings')

app = Celery('saathi_shield')

# Configure Celery with Django settings namespace
app.config_from_object('django.conf:settings', namespace='CELERY')

# Automatically discover tasks from registered Django apps
app.autodiscover_tasks()

@app.task(bind=True, ignore_result=True)
def debug_task(self):
    print(f'Request: {self.request!r}')
