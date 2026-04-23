import os
import datetime
import subprocess
import shutil
import json
import re
import sys

# Configuration
PROJECT_DIR = r"c:\Users\asus\my\almadrasah"
BUILD_OUTPUT_DIR = os.path.join(PROJECT_DIR, "build", "web")
DEPLOY_DIR = os.path.join(PROJECT_DIR, "manar01")
BUILD_ID = datetime.datetime.now().strftime("%Y.%m.%d-%H%M")

def log(message):
    print(message)
    with open("build_log.txt", "a", encoding="utf-8") as f:
        f.write(message + "\n")

def run_command(command, cwd=None):
    log(f"Executing: {command}")
    try:
        subprocess.check_call(command, shell=True, cwd=cwd)
    except subprocess.CalledProcessError as e:
        log(f"❌ Error executing command: {e}")
        sys.exit(1)

def main():
    if os.path.exists("build_log.txt"):
        os.remove("build_log.txt")
        
    log(f"🚀 Starting Senior Architect Build Process")
    log(f"🆔 Build ID: {BUILD_ID}")
    
    # 1. Clean Build
    log("\n🧹 Cleaning previous build...")
    run_command("flutter clean", cwd=PROJECT_DIR)
    
    # 2. Build Web (Disable PWA Service Worker)
    log("\n🔨 Building Flutter Web (Release, No PWA)...")
    # --pwa-strategy=none disables service worker generation (requires Flutter 3.x)
    run_command("flutter build web --release --pwa-strategy=none", cwd=PROJECT_DIR)
    
    if not os.path.exists(BUILD_OUTPUT_DIR):
        log("❌ Build failed. Output directory not found.")
        sys.exit(1)

    # 3. Create version.json
    log("\n📝 Creating version.json...")
    version_data = {
        "version": BUILD_ID,
        "build_date": datetime.datetime.now().isoformat()
    }
    with open(os.path.join(BUILD_OUTPUT_DIR, "version.json"), "w") as f:
        json.dump(version_data, f, indent=2)

    # 4. Inject Build ID into index.html
    log("💉 Injecting Build ID into index.html...")
    index_path = os.path.join(BUILD_OUTPUT_DIR, "index.html")
    with open(index_path, "r", encoding="utf-8") as f:
        index_content = f.read()
    
    # Replace flutter_bootstrap.js with versioned URL
    # Regex to find <script src="flutter_bootstrap.js" ...>
    # Works for both single and double quotes
    index_content = re.sub(
        r'src=["\']flutter_bootstrap\.js["\']', 
        f'src="flutter_bootstrap.js?v={BUILD_ID}"', 
        index_content
    )
    
    # Inject global JS variable for debugging
    if "</head>" in index_content:
        script_tag = f'<script>window.APP_VERSION = "{BUILD_ID}"; console.log("🚀 Manar Build: {BUILD_ID}");</script>'
        index_content = index_content.replace("</head>", f"{script_tag}\n</head>")

    with open(index_path, "w", encoding="utf-8") as f:
        f.write(index_content)

    # 5. Inject Build ID into flutter_bootstrap.js
    log("💉 Injecting Build ID into flutter_bootstrap.js...")
    bootstrap_path = os.path.join(BUILD_OUTPUT_DIR, "flutter_bootstrap.js")
    if os.path.exists(bootstrap_path):
        with open(bootstrap_path, "r", encoding="utf-8") as f:
            bootstrap_content = f.read()
        
        # Replace main.dart.js references with versioned URL
        # Pattern: "main.dart.js" or 'main.dart.js'
        # We handle both quote types
        
        # Count replacements
        count = bootstrap_content.count("main.dart.js")
        log(f"   Found {count} references to main.dart.js")

        bootstrap_content = bootstrap_content.replace('"main.dart.js"', f'"main.dart.js?v={BUILD_ID}"')
        bootstrap_content = bootstrap_content.replace("'main.dart.js'", f"'main.dart.js?v={BUILD_ID}'")
        
        with open(bootstrap_path, "w", encoding="utf-8") as f:
            f.write(bootstrap_content)
    else:
        log("⚠️ Warning: flutter_bootstrap.js not found. Skipping injection (Check if Flutter version supports it).")

    # 6. Deploy to manar01
    log(f"\n📦 Deploying to {DEPLOY_DIR}...")
    if not os.path.exists(DEPLOY_DIR):
        os.makedirs(DEPLOY_DIR)
        
    # Copy files
    for item in os.listdir(BUILD_OUTPUT_DIR):
        s = os.path.join(BUILD_OUTPUT_DIR, item)
        d = os.path.join(DEPLOY_DIR, item)
        if os.path.isdir(s):
            if os.path.exists(d):
                try:
                    shutil.rmtree(d)
                except Exception as e:
                    log(f"   Warning: Could not remove old directory {d}: {e}")
            shutil.copytree(s, d)
        else:
            shutil.copy2(s, d)

    # 7. Write Final web.config
    log("⚙️ Writing final IIS web.config...")
    web_config_content = """<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <system.webServer>
    <staticContent>
      <remove fileExtension=".json" />
      <mimeMap fileExtension=".json" mimeType="application/json" />
      <remove fileExtension=".wasm" />
      <mimeMap fileExtension=".wasm" mimeType="application/wasm" />
      <clientCache cacheControlMode="UseMaxAge" cacheControlMaxAge="365.00:00:00" />
    </staticContent>
    <httpProtocol>
      <customHeaders>
        <add name="Access-Control-Allow-Origin" value="*" />
        <add name="Cross-Origin-Embedder-Policy" value="credentialless" />
        <add name="Cross-Origin-Opener-Policy" value="same-origin" />
      </customHeaders>
    </httpProtocol>
  </system.webServer>

  <!-- No Cache Files (Entry Points) -->
  <location path="index.html">
    <system.webServer>
      <staticContent><clientCache cacheControlMode="DisableCache" /></staticContent>
      <httpProtocol>
        <customHeaders>
           <remove name="Cache-Control" />
           <add name="Cache-Control" value="no-cache, no-store, must-revalidate" />
           <add name="Pragma" value="no-cache" />
           <add name="Expires" value="0" />
        </customHeaders>
      </httpProtocol>
    </system.webServer>
  </location>
  
  <location path="flutter_bootstrap.js">
    <system.webServer>
      <staticContent><clientCache cacheControlMode="DisableCache" /></staticContent>
      <httpProtocol>
        <customHeaders>
           <remove name="Cache-Control" />
           <add name="Cache-Control" value="no-cache, no-store, must-revalidate" />
        </customHeaders>
      </httpProtocol>
    </system.webServer>
  </location>

  <location path="version.json">
    <system.webServer>
      <staticContent><clientCache cacheControlMode="DisableCache" /></staticContent>
      <httpProtocol>
        <customHeaders>
           <remove name="Cache-Control" />
           <add name="Cache-Control" value="no-cache, no-store, must-revalidate" />
        </customHeaders>
      </httpProtocol>
    </system.webServer>
  </location>

  <!-- Immutable Files (Versioned via Query Param) -->
  <location path="main.dart.js">
    <system.webServer>
      <staticContent><clientCache cacheControlMode="UseMaxAge" cacheControlMaxAge="365.00:00:00" /></staticContent>
      <httpProtocol>
        <customHeaders>
          <remove name="Cache-Control" />
          <add name="Cache-Control" value="public, max-age=31536000, immutable" />
        </customHeaders>
      </httpProtocol>
    </system.webServer>
  </location>

  <location path="assets">
    <system.webServer>
      <staticContent><clientCache cacheControlMode="UseMaxAge" cacheControlMaxAge="365.00:00:00" /></staticContent>
      <httpProtocol>
        <customHeaders>
          <remove name="Cache-Control" />
          <add name="Cache-Control" value="public, max-age=31536000, immutable" />
        </customHeaders>
      </httpProtocol>
    </system.webServer>
  </location>
</configuration>"""
    
    with open(os.path.join(DEPLOY_DIR, "web.config"), "w", encoding="utf-8") as f:
        f.write(web_config_content)

    log("\n✅ Build and Deploy Complete!")
    log(f"👉 Version: {BUILD_ID}")

if __name__ == "__main__":
    main()
