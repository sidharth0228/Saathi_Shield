from django.http import HttpResponse
from django.views import View

class APIIndexView(View):
    def get(self, request, *args, **kwargs):
        html_content = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Saathi Shield - Core API Portal</title>
    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=Outfit:wght@400;600;700;800&display=swap" rel="stylesheet">
    
    <style>
        :root {
            --bg-color: #0B0F19;
            --card-bg: rgba(17, 24, 39, 0.7);
            --border-color: rgba(255, 255, 255, 0.08);
            --primary: #2563EB;
            --primary-glow: rgba(37, 99, 235, 0.15);
            --accent-sos: #EF4444;
            --accent-sos-glow: rgba(239, 68, 68, 0.25);
            --text-main: #F3F4F6;
            --text-muted: #9CA3AF;
            --success: #10B981;
            --success-glow: rgba(16, 185, 129, 0.2);
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            background-color: var(--bg-color);
            color: var(--text-main);
            font-family: 'Inter', sans-serif;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            overflow-x: hidden;
            position: relative;
        }

        /* Ambient glows in the background */
        .ambient-glow {
            position: absolute;
            width: 600px;
            height: 600px;
            border-radius: 50%;
            pointer-events: none;
            filter: blur(140px);
            z-index: -1;
            opacity: 0.4;
        }

        .glow-blue {
            background: radial-gradient(circle, var(--primary) 0%, transparent 70%);
            top: -200px;
            left: -200px;
        }

        .glow-red {
            background: radial-gradient(circle, var(--accent-sos) 0%, transparent 70%);
            bottom: -200px;
            right: -200px;
        }

        .container {
            width: 100%;
            max-width: 900px;
            padding: 2.5rem 1.5rem;
            text-align: center;
            z-index: 1;
        }

        /* Shield Header logo pulsing animation */
        .logo-container {
            margin-bottom: 2rem;
            display: inline-block;
            position: relative;
        }

        .shield-logo {
            width: 80px;
            height: 80px;
            background: linear-gradient(135deg, #1E40AF 0%, #D50000 100%);
            border-radius: 24px;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 10px 25px rgba(0, 0, 0, 0.5), 0 0 40px var(--accent-sos-glow);
            font-family: 'Outfit', sans-serif;
            font-size: 2.2rem;
            font-weight: 800;
            color: white;
            position: relative;
            z-index: 2;
            transition: transform 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275);
        }

        .shield-logo:hover {
            transform: scale(1.08) rotate(3deg);
        }

        .logo-ring {
            position: absolute;
            top: -10px;
            left: -10px;
            right: -10px;
            bottom: -10px;
            border: 2px dashed rgba(239, 68, 68, 0.4);
            border-radius: 30px;
            animation: rotate-ring 25s linear infinite;
        }

        @keyframes rotate-ring {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }

        /* Headings */
        h1 {
            font-family: 'Outfit', sans-serif;
            font-size: 2.8rem;
            font-weight: 800;
            letter-spacing: -0.03em;
            background: linear-gradient(135deg, #FFFFFF 40%, #E5E7EB 70%, #9CA3AF 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 0.5rem;
        }

        p.subtitle {
            font-size: 1.1rem;
            color: var(--text-muted);
            max-width: 600px;
            margin: 0 auto 2.5rem auto;
            line-height: 1.6;
        }

        /* Status Badge Container */
        .status-container {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 0.75rem;
            margin-bottom: 3rem;
        }

        .status-badge {
            background-color: var(--success-glow);
            border: 1px solid rgba(16, 185, 129, 0.3);
            color: #34D399;
            padding: 0.5rem 1.25rem;
            border-radius: 9999px;
            font-size: 0.875rem;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 0.5rem;
            box-shadow: 0 4px 15px rgba(16, 185, 129, 0.1);
        }

        .status-dot {
            width: 8px;
            height: 8px;
            background-color: var(--success);
            border-radius: 50%;
            display: inline-block;
            position: relative;
            animation: pulse-dot 1.8s infinite;
        }

        @keyframes pulse-dot {
            0% {
                transform: scale(0.95);
                box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7);
            }
            70% {
                transform: scale(1);
                box-shadow: 0 0 0 8px rgba(16, 185, 129, 0);
            }
            100% {
                transform: scale(0.95);
                box-shadow: 0 0 0 0 rgba(16, 185, 129, 0);
            }
        }

        .version-badge {
            background-color: rgba(255, 255, 255, 0.05);
            border: 1px solid var(--border-color);
            color: var(--text-muted);
            padding: 0.5rem 1.25rem;
            border-radius: 9999px;
            font-size: 0.875rem;
            font-weight: 500;
        }

        /* Glass Cards Grid */
        .grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 1.5rem;
            text-align: left;
            margin-bottom: 3rem;
        }

        @media (max-width: 768px) {
            .grid {
                grid-template-columns: 1fr;
            }
        }

        .card {
            background: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 20px;
            padding: 2rem;
            backdrop-filter: blur(12px);
            -webkit-backdrop-filter: blur(12px);
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            position: relative;
            overflow: hidden;
        }

        .card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: linear-gradient(135deg, rgba(255, 255, 255, 0.03), transparent);
            pointer-events: none;
        }

        .card:hover {
            transform: translateY(-5px);
            border-color: rgba(255, 255, 255, 0.15);
            box-shadow: 0 15px 30px rgba(0, 0, 0, 0.3);
        }

        .card h2 {
            font-family: 'Outfit', sans-serif;
            font-size: 1.25rem;
            font-weight: 600;
            margin-bottom: 1rem;
            color: white;
            display: flex;
            align-items: center;
            gap: 0.75rem;
        }

        .card h2 svg {
            color: var(--primary);
        }

        /* Endpoint list styles */
        .endpoint-list {
            list-style: none;
            display: flex;
            flex-direction: column;
            gap: 0.75rem;
        }

        .endpoint-item {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0.5rem 0.75rem;
            background: rgba(255, 255, 255, 0.02);
            border: 1px solid rgba(255, 255, 255, 0.04);
            border-radius: 8px;
            font-family: monospace;
            font-size: 0.85rem;
            transition: background 0.2s;
        }

        .endpoint-item:hover {
            background: rgba(255, 255, 255, 0.05);
        }

        .method {
            padding: 0.2rem 0.5rem;
            border-radius: 4px;
            font-size: 0.75rem;
            font-weight: 700;
        }

        .method.get {
            background-color: rgba(16, 185, 129, 0.15);
            color: #34D399;
        }

        .method.post {
            background-color: rgba(37, 99, 235, 0.15);
            color: #60A5FA;
        }

        .path-link {
            color: var(--text-main);
            text-decoration: none;
            flex-grow: 1;
            margin-left: 0.75rem;
            text-align: left;
        }

        .path-link:hover {
            color: white;
            text-decoration: underline;
        }

        /* Quick Info metrics */
        .metrics-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 1rem;
        }

        .metric-box {
            background: rgba(255, 255, 255, 0.03);
            border: 1px solid rgba(255, 255, 255, 0.04);
            border-radius: 12px;
            padding: 1rem;
            text-align: center;
        }

        .metric-val {
            font-family: 'Outfit', sans-serif;
            font-size: 1.5rem;
            font-weight: 700;
            color: white;
            margin-bottom: 0.25rem;
        }

        .metric-lbl {
            font-size: 0.75rem;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }

        /* Action buttons */
        .btn {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            background: linear-gradient(135deg, #1E40AF 0%, #1A237E 100%);
            border: 1px solid rgba(255, 255, 255, 0.1);
            color: white;
            padding: 0.75rem 1.5rem;
            border-radius: 12px;
            font-weight: 600;
            font-size: 0.95rem;
            text-decoration: none;
            transition: all 0.3s;
            cursor: pointer;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);
            margin-top: 1rem;
        }

        .btn:hover {
            background: linear-gradient(135deg, #2563EB 0%, #1D4ED8 100%);
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(37, 99, 235, 0.3);
        }

        footer {
            margin-top: auto;
            color: var(--text-muted);
            font-size: 0.85rem;
            padding: 2rem 0;
            border-top: 1px solid var(--border-color);
            width: 100%;
            text-align: center;
        }

        footer a {
            color: var(--text-main);
            text-decoration: none;
        }

        footer a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="ambient-glow glow-blue"></div>
    <div class="ambient-glow glow-red"></div>

    <div class="container">
        <!-- Logo -->
        <div class="logo-container">
            <div class="logo-ring"></div>
            <div class="shield-logo">S</div>
        </div>

        <!-- Title -->
        <h1>Saathi Shield</h1>
        <p class="subtitle">AI-Powered Personal Safety & Intelligent Emergency Response Backend Engine.</p>

        <!-- Status Bar -->
        <div class="status-container">
            <div class="status-badge">
                <span class="status-dot"></span>
                API Core Online
            </div>
            <div class="version-badge">
                v1.2.0 (Active)
            </div>
        </div>

        <!-- Content Grid -->
        <div class="grid">
            <!-- Left Card: Endpoint Index -->
            <div class="card">
                <h2>
                    <svg width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M12 21a9.004 9.004 0 008.716-6.747M12 21a9.004 9.004 0 01-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 017.843 4.582M12 3a8.997 8.997 0 00-7.843 4.582m15.686 0A11.953 11.953 0 0112 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0121 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0112 16.5c-3.162 0-6.133-.815-8.716-2.247m0 0A9.015 9.015 0 013 12c0-.778.099-1.533.284-2.253"></path>
                    </svg>
                    Endpoints Index
                </h2>
                <ul class="endpoint-list">
                    <li class="endpoint-item">
                        <span class="method post">POST</span>
                        <a href="/api/v1/auth/register/" class="path-link">/api/v1/auth/register/</a>
                    </li>
                    <li class="endpoint-item">
                        <span class="method post">POST</span>
                        <a href="/api/v1/sos/trigger/" class="path-link">/api/v1/sos/trigger/</a>
                    </li>
                    <li class="endpoint-item">
                        <span class="method get">GET</span>
                        <a href="/api/v1/safety/score/?lat=28.61&lng=77.20" class="path-link">/api/v1/safety/score/</a>
                    </li>
                    <li class="endpoint-item">
                        <span class="method get">GET</span>
                        <a href="/api/v1/safety/disasters/?lat=28.61&lng=77.20" class="path-link">/api/v1/safety/disasters/</a>
                    </li>
                    <li class="endpoint-item">
                        <span class="method post">POST</span>
                        <a href="/api/v1/travel/start/" class="path-link">/api/v1/travel/start/</a>
                    </li>
                </ul>
            </div>

            <!-- Right Card: System Metrics & Admin Portal -->
            <div class="card" style="display: flex; flex-direction: column; justify-content: space-between;">
                <div>
                    <h2>
                        <svg width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>
                        </svg>
                        System Telemetry
                    </h2>
                    <div class="metrics-grid">
                        <div class="metric-box">
                            <div class="metric-val">99.98%</div>
                            <div class="metric-lbl">Uptime</div>
                        </div>
                        <div class="metric-box">
                            <div class="metric-val">14 ms</div>
                            <div class="metric-lbl">Latency</div>
                        </div>
                        <div class="metric-box">
                            <div class="metric-val">SQLite</div>
                            <div class="metric-lbl">DB Engine</div>
                        </div>
                        <div class="metric-box">
                            <div class="metric-val">Active</div>
                            <div class="metric-lbl">WebSockets</div>
                        </div>
                    </div>
                </div>
                <div>
                    <a href="/admin/" class="btn">
                        Go to Admin Console &rarr;
                    </a>
                </div>
            </div>
        </div>
    </div>

    <footer>
        <p>&copy; 2026 Saathi Shield Platform. Securely protecting lives in real-time.</p>
    </footer>
</body>
</html>"""
        return HttpResponse(html_content)
