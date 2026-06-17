#!/usr/bin/env python3
"""
Revolutionary Technology - High-Performance Log Parser & Rule Generator (V2)
Features: NVIDIA CUDA Acceleration, Numba JIT, Multicore Processing, LRU Cache.
"""
import typer
import re
import socket
import multiprocessing
import numpy as np
from numba import njit, cuda
from pathlib import Path
from functools import lru_cache
from concurrent.futures import ProcessPoolExecutor

app = typer.Typer(help="RT Enterprise Log Parser & Automated Rule Generator")

# =======================================================================
# 1. MEMORY CACHE LAYER: Optimize Network Operations
# =======================================================================
@lru_cache(maxsize=8192)
def resolve_hostname(ip_address: str) -> str:
    """Caches reverse DNS lookups in RAM to prevent redundant network delays."""
    try:
        return socket.gethostbyaddr(ip_address)[0]
    except socket.herror:
        return "Unknown_Host"

# =======================================================================
# 2. NVIDIA CUDA LAYER: GPU-Accelerated Mathematics
# =======================================================================
@cuda.jit
def gpu_port_aggregation(port_array, counts):
    """
    Executes on the NVIDIA GPU.
    Uses atomic operations to safely count massive arrays of port hits
    across thousands of simultaneous GPU threads.
    """
    idx = cuda.grid(1)
    if idx < port_array.size:
        port = port_array[idx]
        if 0 <= port < 65536:
            # Safely increment the count for this specific port
            cuda.atomic.add(counts, port, 1)

# =======================================================================
# 3. NJIT CPU FALLBACK LAYER: Compiled Machine Code
# =======================================================================
@njit
def fast_port_aggregation_cpu(port_array: np.ndarray) -> np.ndarray:
    """Fallback compiled C-speed math for servers without NVIDIA GPUs."""
    counts = np.zeros(65536, dtype=np.int32)
    for p in port_array:
        if 0 <= p < 65536:
            counts[p] += 1
    return counts

# =======================================================================
# 4. MULTICORE LAYER: Parallel Text Processing
# =======================================================================
def process_log_chunk(lines: list) -> list:
    """Worker function for multicore regex extraction."""
    log_pattern = re.compile(r"SRC=(?P<src>\d+\.\d+\.\d+\.\d+).*?DPT=(?P<port>\d+).*?PROTO=(?P<proto>\w+)")
    
    extracted_data = []
    for line in lines:
        match = log_pattern.search(line)
        if match:
            extracted_data.append({
                "src": match.group("src"),
                "port": int(match.group("port")),
                "proto": match.group("proto")
            })
    return extracted_data

def chunk_file(filepath: Path, chunk_size: int = 10000):
    """Yields chunks of a log file for parallel multicore processing."""
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        chunk = []
        for line in f:
            chunk.append(line)
            if len(chunk) >= chunk_size:
                yield chunk
                chunk = []
        if chunk:
            yield chunk

# =======================================================================
# 5. CLI & EXECUTION LAYER
# =======================================================================
@app.command()
def generate(
    log_file: Path = typer.Argument(..., help="Path to the raw firewall/syslog file"),
    output_dir: Path = typer.Option(Path.cwd() / "docs", "--output", "-o"),
    threshold: int = typer.Option(100, "--threshold", "-t", help="Minimum hits to trigger an auto-block"),
    cores: int = typer.Option(multiprocessing.cpu_count(), "--cores", "-c"),
    use_gpu: bool = typer.Option(True, "--gpu/--no-gpu", help="Attempt NVIDIA CUDA acceleration")
):
    if not log_file.exists():
        typer.secho(f"Error: Log file '{log_file}' missing.", fg=typer.colors.RED)
        raise typer.Exit(1)

    typer.secho(f"[*] Parsing logs via {cores} CPU cores...", fg=typer.colors.CYAN)
    
    # --- PHASE 1: Multicore Log Parsing ---
    all_hits = []
    with ProcessPoolExecutor(max_workers=cores) as executor:
        for res in executor.map(process_log_chunk, chunk_file(log_file)):
            all_hits.extend(res)

    if not all_hits:
        typer.secho("[-] No valid firewall drops found.", fg=typer.colors.YELLOW)
        raise typer.Exit(0)

    # Extract ports into a highly-optimized numpy array
    port_array = np.array([hit['port'] for hit in all_hits], dtype=np.int32)
    port_counts = np.zeros(65536, dtype=np.int32)

    # --- PHASE 2: GPU/CPU Aggregation ---
    gpu_active = False
    if use_gpu and cuda.is_available():
        try:
            typer.secho("[*] Routing data through NVIDIA GPU (CUDA)...", fg=typer.colors.MAGENTA)
            # Send data to VRAM
            d_port_array = cuda.to_device(port_array)
            d_counts = cuda.to_device(port_counts)
            
            # Configure CUDA Grid/Block dimensions
            threads_per_block = 256
            blocks_per_grid = (port_array.size + (threads_per_block - 1)) // threads_per_block
            
            # Execute Kernel
            gpu_port_aggregation[blocks_per_grid, threads_per_block](d_port_array, d_counts)
            
            # Retrieve data from VRAM
            port_counts = d_counts.copy_to_host()
            gpu_active = True
        except Exception as e:
            typer.secho(f"[!] GPU execution failed: {e}. Falling back to CPU.", fg=typer.colors.YELLOW)

    if not gpu_active:
        typer.secho("[*] Routing data through Numba JIT CPU compiler...", fg=typer.colors.CYAN)
        port_counts = fast_port_aggregation_cpu(port_array)
    
    # Filter ports exceeding our threshold
    targeted_ports = [port for port, count in enumerate(port_counts) if count >= threshold]

    # --- PHASE 3: Caching & Export ---
    output_dir.mkdir(parents=True, exist_ok=True)
    out_path = output_dir / "rt_auto_generated_rules.txt"
    
    typer.secho(f"[*] Resolving IP Hostnames via LRU RAM Cache...", fg=typer.colors.CYAN)
    with open(out_path, "w") as f:
        f.write("# RT Auto-Generated Defense Rules\n")
        for hit in all_hits:
            if hit['port'] in targeted_ports:
                host = resolve_hostname(hit['src'])
                f.write(f"tcp|in|d={hit['port']}|s={hit['src']} # Auto-Blocked: {host}\n")
                
    typer.secho(f"[+] Success! Exported to: {out_path}", fg=typer.colors.GREEN)

if __name__ == "__main__":
    app()
