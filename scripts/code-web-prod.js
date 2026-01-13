#!/usr/bin/env node
/*---------------------------------------------------------------------------------------------
 *  StackCodeSy - Production Web Server
 *  Serves pre-compiled VSCode web files with custom authentication
 *--------------------------------------------------------------------------------------------*/

const express = require('express');
const path = require('path');
const fs = require('fs');

const APP_ROOT = path.join(__dirname, '..');
const WORKBENCH_HTML = path.join(APP_ROOT, 'src/vs/code/browser/workbench/workbench.html');
const HOST = process.env.HOST || '0.0.0.0';
const PORT = parseInt(process.env.PORT || '8080', 10);

// Parse command line arguments
const args = process.argv.slice(2);
let folderUri = undefined;

for (let i = 0; i < args.length; i++) {
    if (args[i] === '--host' && i + 1 < args.length) {
        // Skip, using env var
    } else if (args[i] === '--port' && i + 1 < args.length) {
        // Skip, using env var
    } else if (args[i] === '--folder-uri' && i + 1 < args.length) {
        folderUri = args[++i];
    }
}

const app = express();

// Serve static files from out/ directory (compiled code)
app.use('/out', express.static(path.join(APP_ROOT, 'out'), {
    setHeaders: (res, filePath) => {
        // Set correct MIME types
        if (filePath.endsWith('.js')) {
            res.setHeader('Content-Type', 'application/javascript');
        } else if (filePath.endsWith('.css')) {
            res.setHeader('Content-Type', 'text/css');
        }
        // Disable caching in development
        if (process.env.NODE_ENV === 'development') {
            res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
        }
    }
}));

// Serve resources (icons, manifests, etc.)
app.use('/resources', express.static(path.join(APP_ROOT, 'resources')));

// Serve extensions
app.use('/extensions', express.static(path.join(APP_ROOT, 'extensions')));

// Serve node_modules for web dependencies
app.use('/node_modules', express.static(path.join(APP_ROOT, 'node_modules')));

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ status: 'ok', version: '1.0.0' });
});

// Main workbench route
app.get('/', (req, res) => {
    try {
        let html = fs.readFileSync(WORKBENCH_HTML, 'utf-8');

        const webConfiguration = {
            folderUri: folderUri || { scheme: 'memfs', path: '/workspace' },
            productConfiguration: {
                nameShort: 'StackCodeSy',
                nameLong: 'StackCodeSy - Code Editor',
                applicationName: 'stackcodesy',
                dataFolderName: '.stackcodesy',
                version: '1.107.0',
                extensionsGallery: {
                    serviceUrl: 'https://marketplace.visualstudio.com/_apis/public/gallery',
                    itemUrl: 'https://marketplace.visualstudio.com/items',
                    resourceUrlTemplate: 'https://marketplace.visualstudio.com/_apis/public/gallery/publisher/{publisher}/extension/{name}/{version}/assetbyname/{target}',
                },
            },
            enableWorkspaceTrust: false,
            remoteAuthority: undefined,
        };

        // Replace template variables
        html = html.replace(/{{WORKBENCH_WEB_BASE_URL}}/g, '');
        html = html.replace('{{WORKBENCH_WEB_CONFIGURATION}}', JSON.stringify(webConfiguration).replace(/"/g, '&quot;'));
        html = html.replace('{{WORKBENCH_AUTH_SESSION}}', '');
        html = html.replace('{{WORKBENCH_NLS_FALLBACK_URL}}', '/out/nls.messages.js');
        html = html.replace('{{WORKBENCH_NLS_URL}}', '/out/nls.messages.js');

        res.setHeader('Content-Type', 'text/html');
        res.send(html);
    } catch (error) {
        console.error('Error serving workbench:', error);
        res.status(500).send(`
            <html>
                <head><title>StackCodeSy - Error</title></head>
                <body>
                    <h1>Error Loading StackCodeSy</h1>
                    <p>Failed to load the code editor. Please ensure the application is properly built.</p>
                    <pre>${error.message}</pre>
                    <p><strong>Debug Info:</strong></p>
                    <ul>
                        <li>APP_ROOT: ${APP_ROOT}</li>
                        <li>Out directory exists: ${fs.existsSync(path.join(APP_ROOT, 'out'))}</li>
                        <li>Workbench HTML exists: ${fs.existsSync(WORKBENCH_HTML)}</li>
                    </ul>
                </body>
            </html>
        `);
    }
});

// Catch-all for other routes
app.use((req, res) => {
    console.log(`404: ${req.method} ${req.url}`);
    res.status(404).send('Not Found');
});

// Start server
app.listen(PORT, HOST, () => {
    console.log('========================================');
    console.log('  StackCodeSy - Code Editor');
    console.log('========================================');
    console.log(`  Server running at: http://${HOST}:${PORT}`);
    console.log(`  Environment: ${process.env.NODE_ENV || 'production'}`);
    console.log(`  Folder: ${folderUri || 'default workspace'}`);
    console.log('========================================');
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM signal received: closing server');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('SIGINT signal received: closing server');
    process.exit(0);
});
