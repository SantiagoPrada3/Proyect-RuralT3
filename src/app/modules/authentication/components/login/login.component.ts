import { Component, OnInit, OnDestroy } from '@angular/core';
import { Router, RouterModule } from '@angular/router';
import { NotificationService } from '../../../../shared/services/notification.service';
import { CommonModule } from '@angular/common';
import { GoogleRegisterComponent } from '../google-register/google-register.component';
import { LoginService } from '../../services/login.service';

@Component({
  selector: 'app-login',
  imports: [RouterModule, CommonModule, GoogleRegisterComponent],
  templateUrl: './login.component.html',
  styleUrl: './login.component.css'
})
export class LoginComponent implements OnInit, OnDestroy {
  hasMetaMask: boolean = false;
  showGoogleRegisterForm: boolean = false;
  googleUserEmail: string = '';
  private googleInitialized: boolean = false;
  showAccountCreationSuccess: boolean = false;

  constructor(
    private router: Router,
    private notificationService: NotificationService,
    private loginService: LoginService
  ) {}

  ngOnInit() {
    // Check if MetaMask is installed
    this.hasMetaMask = typeof window.ethereum !== 'undefined' && window.ethereum.isMetaMask;

    // Initialize Google Sign-In
    this.initializeGoogleSignIn();
  }

  ngOnDestroy() {
    // Clean up Google Sign-In if initialized
    if (this.googleInitialized && typeof window !== 'undefined' && (window as any).google) {
      // Note: Google Identity Services doesn't have a direct cleanup method
    }
  }

  private initializeGoogleSignIn() {
    // Only run in browser environment
    if (typeof window === 'undefined' || typeof document === 'undefined') {
      return;
    }

    // Check if already initialized
    if (this.googleInitialized) {
      return;
    }

    // Load Google Identity Services script
    const script = document.createElement('script');
    script.src = 'https://accounts.google.com/gsi/client';
    script.async = true;
    script.defer = true;
    script.onload = () => {
      this.googleInitialized = true;
      console.log('Google Identity Services loaded');
    };
    script.onerror = () => {
      console.error('Failed to load Google Identity Services');
      this.notificationService.error('Error', 'No se pudo cargar el servicio de Google', 3000);
    };
    document.head.appendChild(script);
  }

  async connectWallet(walletType: string) {
    try {
      // Check if Ethereum provider exists
      if (typeof window.ethereum === 'undefined') {
        this.notificationService.error('Billetera no encontrada', 'Por favor instale MetaMask para continuar', 5000);
        return;
      }

      // Request account access
      const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
      const account = accounts[0];

      // Get network information
      const chainId = await window.ethereum.request({ method: 'eth_chainId' });

      // Get balance
      const balanceHex = await window.ethereum.request({
        method: 'eth_getBalance',
        params: [account, 'latest'],
      });

      // Convert balance from hex to decimal
      const balanceWei = parseInt(balanceHex, 16);
      const balanceEth = (balanceWei / 1e18).toFixed(4);

      // Store wallet info in localStorage (in a real app, you'd use a service)
      localStorage.setItem('walletAddress', account);
      localStorage.setItem('chainId', chainId);
      localStorage.setItem('balance', balanceEth);

      // Show success message
      this.notificationService.success('Conexión exitosa', `Conectado con ${account.substring(0, 6)}...${account.substring(account.length - 4)}`, 3000);

      // Navigate to dashboard
      this.router.navigate(['/dashboard']);
    } catch (error) {
      console.error('Error connecting wallet:', error);
      this.notificationService.error('Error de conexión', 'No se pudo conectar con la billetera. Por favor intente nuevamente.', 5000);
    }
  }

  // Google Sign In method for account creation
  createAccountWithGoogle() {
    // Check if Google Identity Services is loaded
    if (!this.googleInitialized) {
      this.notificationService.error('Error', 'El servicio de Google aún no está listo. Por favor intente nuevamente.', 3000);
      return;
    }

    // Ensure we're in browser environment
    if (typeof window === 'undefined' || typeof document === 'undefined') {
      return;
    }

    // Initialize Google Sign-In client
    const client = (window as any).google?.accounts.oauth2.initTokenClient({
      client_id: '137071039440-p1av1ochvuc1dhn3vt4sio6t0i5s5ac3.apps.googleusercontent.com',
      scope: 'email profile',
      callback: (response: any) => {
        if (response.error) {
          console.error('Google Sign-In error:', response.error);
          this.notificationService.error('Error de autenticación', 'No se pudo iniciar sesión con Google: ' + response.error_description, 3000);
          return;
        }

        // Get user info using the access token
        fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
          headers: {
            Authorization: `Bearer ${response.access_token}`
          }
        })
        .then(response => response.json())
        .then(userInfo => {
          this.showGoogleRegisterForm = true;
          this.googleUserEmail = userInfo.email;
          this.notificationService.info('Crear cuenta con Google', 'Por favor completa tu información', 3000);
        })
        .catch(error => {
          console.error('Error fetching user info:', error);
          this.notificationService.error('Error', 'No se pudo obtener la información del usuario', 3000);
        });
      }
    });

    // Prompt user to sign in
    client.requestAccessToken();
  }

  onGoogleRegistrationComplete(userData: {firstName: string, lastName: string, phone: string, address: string, password: string}) {
    // Create account with Google and password
    const accountData = {
      firstName: userData.firstName,
      lastName: userData.lastName,
      email: this.googleUserEmail,
      phone: userData.phone,
      address: userData.address,
      password: userData.password
    };

    this.loginService.createAccountWithGoogleAndPassword(accountData).subscribe({
      next: (success) => {
        if (success) {
          // Save user profile to localStorage
          const userProfile = {
            firstName: userData.firstName,
            lastName: userData.lastName,
            email: this.googleUserEmail,
            phone: userData.phone,
            address: userData.address,
            notifications: true,
            newsletter: true
          };

          this.loginService.saveUserProfile(userProfile);

          // Show account creation success message
          this.showGoogleRegisterForm = false;
          this.showAccountCreationSuccess = true;
          this.notificationService.success('Cuenta creada', 'Tu cuenta ha sido creada exitosamente. Ahora conecta tu billetera MetaMask.', 5000);
        } else {
          this.notificationService.error('Error', 'No se pudo crear la cuenta. Por favor intente nuevamente.', 3000);
        }
      },
      error: (error) => {
        console.error('Account creation error:', error);
        this.notificationService.error('Error', 'No se pudo crear la cuenta. Por favor intente nuevamente.', 3000);
      }
    });
  }

  onGoogleRegistrationCancel() {
    this.showGoogleRegisterForm = false;
    this.notificationService.info('Creación de cuenta cancelada', 'Puedes iniciar sesión con otro método', 3000);
  }

  onContinueToWallet() {
    this.showAccountCreationSuccess = false;
    this.notificationService.info('Conectar billetera', 'Por favor conecta tu billetera MetaMask para continuar', 3000);
  }

  connectCoinbase() {
    // For Coinbase Wallet, you would typically use their SDK
    // This is a simplified version for demonstration
    this.notificationService.info('Conexión Coinbase', 'Conexión con Coinbase Wallet no implementada en esta demo', 3000);
    this.router.navigate(['/dashboard']);
  }

  connectWalletConnect() {
    // For WalletConnect, we'll open the network selection modal
    // This is a simplified version for demonstration
    this.openNetworkSelectionModal();
  }

  openNetworkSelectionModal() {
    const modal = document.getElementById('networkSelectionModal');
    if (modal) {
      modal.style.display = 'block';
    }
  }

  closeNetworkSelectionModal() {
    const modal = document.getElementById('networkSelectionModal');
    if (modal) {
      modal.style.display = 'none';
    }
  }

  async connectToTestNetwork(network: string) {
    try {
      // Check if Ethereum provider exists
      if (typeof window.ethereum === 'undefined') {
        this.notificationService.error('Billetera no encontrada', 'Por favor instale MetaMask para continuar', 5000);
        this.closeNetworkSelectionModal();
        return;
      }

      // Define network parameters
      const networkParams: { [key: string]: { chainId: string, name: string } } = {
        holesky: { chainId: '0x4268', name: 'Holesky' },
        sepolia: { chainId: '0xaa36a7', name: 'Sepolia' },
        hoodi: { chainId: '0x88bb0', name: 'Ethereum Hoodi' },
        ephemery: { chainId: '0x259df89', name: 'Ephemery Testnet' }
      };

      // Get selected network
      const selectedNetwork = networkParams[network];
      if (!selectedNetwork) {
        this.notificationService.error('Red no válida', 'La red seleccionada no es válida', 5000);
        this.closeNetworkSelectionModal();
        return;
      }

      // Switch to the selected network
      try {
        await window.ethereum.request({
          method: 'wallet_switchEthereumChain',
          params: [{ chainId: selectedNetwork.chainId }],
        });
      } catch (switchError: any) {
        // This error code indicates that the chain has not been added to MetaMask.
        if (switchError.code === 4902) {
          try {
            // Define RPC URLs and block explorer URLs for each network
            const networkConfig: { [key: string]: { rpcUrl: string, blockExplorerUrl: string } } = {
              holesky: {
                rpcUrl: 'https://holesky.drpc.org',
                blockExplorerUrl: 'https://holesky.etherscan.io'
              },
              sepolia: {
                rpcUrl: 'https://ethereum-sepolia-rpc.publicnode.com',
                blockExplorerUrl: 'https://sepolia.etherscan.io'
              },
              hoodi: {
                rpcUrl: 'https://hoodi.drpc.org',
                blockExplorerUrl: 'https://hoodi.etherscan.io'
              },
              ephemery: {
                rpcUrl: 'https://otter.bordel.wtf/erigon',
                blockExplorerUrl: 'https://explorer.ephemery.dev'
              }
            };

            const config = networkConfig[network] || {
              rpcUrl: 'https://ethereum-rpc.publicnode.com',
              blockExplorerUrl: 'https://etherscan.io'
            };

            await window.ethereum.request({
              method: 'wallet_addEthereumChain',
              params: [
                {
                  chainId: selectedNetwork.chainId,
                  chainName: selectedNetwork.name,
                  nativeCurrency: {
                    name: network === 'sepolia' ? 'SepoliaETH' : 'ETH',
                    symbol: network === 'sepolia' ? 'SepoliaETH' : 'ETH',
                    decimals: 18
                  },
                  rpcUrls: [config.rpcUrl],
                  blockExplorerUrls: [config.blockExplorerUrl]
                },
              ],
            });
          } catch (addError) {
            console.error('Failed to add network:', addError);
            this.notificationService.error('Error', 'No se pudo agregar la red', 5000);
            this.closeNetworkSelectionModal();
            return;
          }
        } else {
          console.error('Failed to switch network:', switchError);
          this.notificationService.error('Error', 'No se pudo cambiar a la red seleccionada', 5000);
          this.closeNetworkSelectionModal();
          return;
        }
      }

      // Request account access
      const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
      const account = accounts[0];

      // Get network information
      const chainId = await window.ethereum.request({ method: 'eth_chainId' });

      // Get balance
      const balanceHex = await window.ethereum.request({
        method: 'eth_getBalance',
        params: [account, 'latest'],
      });

      // Convert balance from hex to decimal
      const balanceWei = parseInt(balanceHex, 16);
      const balanceEth = (balanceWei / 1e18).toFixed(4);

      // Store wallet info in localStorage
      localStorage.setItem('walletAddress', account);
      localStorage.setItem('chainId', chainId);
      localStorage.setItem('balance', balanceEth);

      // Close modal
      this.closeNetworkSelectionModal();

      // Show success message
      this.notificationService.success('Conexión exitosa', `Conectado a ${selectedNetwork.name}`, 3000);

      // Navigate to dashboard
      this.router.navigate(['/dashboard']);
    } catch (error) {
      console.error('Error connecting to test network:', error);
      this.notificationService.error('Error de conexión', 'No se pudo conectar con la red de prueba. Por favor intente nuevamente.', 5000);
      this.closeNetworkSelectionModal();
    }
  }
}
