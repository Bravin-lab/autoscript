import asyncio
import aiohttp
import sys
import os

# Colors for terminal
GREEN = "\033[92m"
YELLOW = "\033[93m"
RED = "\033[91m"
CYAN = "\033[96m"
RESET = "\033[0m"

# CDN Server keywords to look for
CDNS = ["cloudflare", "cloudfront", "fastly", "akamai", "sucuri"]

async def check_domain(session, domain):
    url = f"http://{domain}"
    try:
        # We follow redirects but check the final server
        async with session.head(url, timeout=5, allow_redirects=True) as response:
            status = response.status
            server = response.headers.get("Server", "Unknown").lower()
            
            is_cdn = any(cdn in server for cdn in CDNS)
            
            if status == 200:
                if is_cdn:
                    print(f"{GREEN}[+] SUCCESS: {domain} | Status: {status} | Server: {server}{RESET}")
                    with open("results.txt", "a") as f:
                        f.write(f"{domain} (Status: {status}, Server: {server})\n")
                else:
                    print(f"{YELLOW}[-] ACCESSIBLE: {domain} | Status: {status} | Server: {server} (Not CDN?){RESET}")
            else:
                print(f"{RED}[x] FAILED: {domain} | Status: {status}{RESET}")
                
    except asyncio.TimeoutError:
        print(f"{RED}[x] TIMEOUT: {domain}{RESET}")
    except Exception as e:
        # print(f"{RED}[x] ERROR: {domain} ({e}){RESET}") # Uncomment for debugging
        pass

async def main():
    if not os.path.exists("domains.txt"):
        print(f"{RED}Error: domains.txt not found! Create it with one domain per line.{RESET}")
        return

    with open("domains.txt", "r") as f:
        domains = [line.strip() for line in f if line.strip()]

    if not domains:
        print(f"{RED}Error: domains.txt is empty!{RESET}")
        return

    print(f"{CYAN}Starting scan on {len(domains)} domains...{RESET}")
    print(f"{CYAN}Results will be saved to results.txt{RESET}")
    
    # Clear previous results
    with open("results.txt", "w") as f:
        pass

    # Limit concurrency to 100 at a time to avoid crashing the local network
    connector = aiohttp.TCPConnector(limit=100, ssl=False)
    async with aiohttp.ClientSession(connector=connector) as session:
        tasks = []
        for domain in domains:
            tasks.append(check_domain(session, domain))
        
        await asyncio.gather(*tasks)

    print(f"\n{CYAN}Scan complete! Check results.txt for valid bug hosts.{RESET}")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print(f"\n{RED}Scan cancelled by user.{RESET}")
        sys.exit(0)
