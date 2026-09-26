from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from alerts.views import EvidenceUploadView
from saathi_shield.views import APIIndexView

urlpatterns = [
    path('', APIIndexView.as_view(), name='api-index'),
    path('admin/', admin.site.urls),
    
    # API endpoints
    path('api/v1/', include('authentication.urls')),
    path('api/v1/sos/', include('alerts.urls')),
    path('api/v1/travel/', include('travel.urls')),
    path('api/v1/community/', include('community.urls')),
    path('api/v1/notifications/', include('notifications.urls')),
    path('api/v1/safety/', include('ai_engine.urls')),
    path('api/v1/evidence/upload/', EvidenceUploadView.as_view(), name='evidence-upload-spec'),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

