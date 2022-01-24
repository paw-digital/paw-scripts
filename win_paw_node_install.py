import os
import sys
from subprocess import Popen, check_output
import requests
import zipfile
import re

# Get the current working directory
cwd = os.getcwd()

# Set constants
barSize = 20
installerFileUrl = 'https://github.com/paw-digital/paw-node/releases/latest/download/win64-paw_node.zip'
zipFilename = '_tmp_paw_node.zip'
rpcPort = 7046
rpcUrl = f'http://[::1]:{rpcPort}'
downloadBarSize = 100
extractedName = 'paw-node-1.4.0-win64'
targetPath = f'{cwd}\\{extractedName}'
dataPath = f'{targetPath}\\data'
binPath = f'{targetPath}\\bin'

# Content of config-node.toml
node_config = f'\
    [node]\n\
    # Enable or disable voting. Enabling this option requires additional system resources, namely increased CPU, bandwidth and disk usage.\n\
    # type:bool\n\
    enable_voting = true\n\
    \n\
    # The external port number of this node (NAT). Only used if external_address is set.\n\
    # type:uint16\n\
    external_port = 7045\n\
    \n\
    \n\
    [rpc]\n\
    \n\
    # Enable or disable RPC\n\
    # type:bool\n\
    enable = true\n\
'

# Content of config-rpc.toml
rpc_config = f'\
    # Bind address for the RPC server.\n\
    # type:string,ip\n\
    address = "::1"\n\
    \n\
    # Enable or disable control-level requests.\n\
    # WARNING: Enabling this gives anyone with RPC access the ability to stop the node and access wallet funds.\n\
    # type:bool\n\
    enable_control = false\n\
    \n\
    # Listening port for the RPC server.\n\
    # type:uint16\n\
    port = {rpcPort}\n\
'

def download():
    with open(f'{targetPath}\\{zipFilename}', "wb") as f:
        response = requests.get(installerFileUrl, stream=True, allow_redirects=True)
        total_length = response.headers.get('content-length')
        
        if total_length is None: # no content length header
            f.write(response.content)
        else:
            dl = 0
            total_length = int(total_length)
            for data in response.iter_content(chunk_size=4096):
                dl += len(data)
                f.write(data)
                percentage = int(100 * dl / total_length)
                barDone = int(barSize * dl / total_length)
                sys.stdout.write("\rDownloading %s [%s%s] %s" % ("Paw node", '=' * barDone, ' ' * (barSize-barDone), str(percentage) + '%') )    
                sys.stdout.flush()

try:
    
    print ("Starting...")
    
    # Crete target dir
    os.mkdir(targetPath)
    
    # Download Node
    download()
    
    # Extract node
    print("\nExtracting... ", end='')
    with zipfile.ZipFile(f'{targetPath}\\{zipFilename}', 'r') as zip_ref:
        names = [info.filename for info in zip_ref.infolist() if info.is_dir()]
        zip_ref.extractall(targetPath)
    print("Extracted!")
        
    # Delete zipped package
    os.remove(f'{targetPath}\\{zipFilename}')
    
    # Rename bin directory
    os.rename(f'{targetPath}\\{names[0].split("/")[0]}', binPath)
    
    # Crete data path
    os.mkdir(dataPath)
    
    # Write config-node.toml
    with open(f'{dataPath}\\config-node.toml', "w") as f:
        f.write(node_config)
        
    # Write config-rpc.toml
    with open(f'{dataPath}\\config-rpc.toml', "w") as f:
        f.write(rpc_config)
    
    #Start daemon
    Popen(f'start /b "PAW Node" "{binPath}\\paw_node.exe" --daemon --data_path={dataPath}', shell=True)
    print(f'\nNode is running! RPC Address: {rpcUrl}')
            
    print("\nTesting node RPC...")    
    r = requests.post(rpcUrl, json={"action": "block_count"})
    if("count" in r.json()):
        print("All ok...")
    else:
        raise Exception("RPC test failed")
            
    # Crete wallet
    walletOut = check_output(f'{binPath}\\paw_node.exe --wallet_create --data_path={dataPath}')
    wallet = re.sub('[^A-Za-z0-9]+', '', walletOut.decode("utf-8"))
    
    # Create Representative Account
    accountOut = check_output(f'{binPath}\\paw_node.exe --account_create --wallet={wallet} --data_path={dataPath}')
    account = re.sub('[^A-Za-z0-9 _]+', '', accountOut.decode("utf-8")).split()[1]
    
    # Print Account Info
    print(f'\nYour tribe has been created: {account}')
    print('Please send at least 0.01 PAW to this account to open it.') 
    print('Your tribe will start voting once its open and has over 1000 PAW delegated.')
    
    # Show Private Keys
    print("\nPlease store your private key safely and confidentially!")
    walletKeysOut = check_output(f'{binPath}\\paw_node.exe --wallet_decrypt_unsafe --wallet={wallet} --data_path={dataPath}')
    walletKeys = re.sub('[^A-Za-z0-9 _]+', '', walletKeysOut.decode("utf-8")).split()
    print(f'Seed: {walletKeys[1]}')
    print(f'Account: {walletKeys[2]}')
    print(f'Private Key: {walletKeys[4]}')
    
    print("\nTo keep node running, do not close this window.")
    
except Exception as error:
    print(error)