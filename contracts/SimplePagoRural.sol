// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SimplePagoRural
 * @dev Contrato inteligente simplificado para pagos rurales
 */
contract SimplePagoRural {
    address public owner;
    mapping(address => uint256) public balances;
    mapping(address => bool) public registeredUsers;
    
    event UserRegistered(address user);
    event Deposit(address user, uint256 amount);
    event Transfer(address from, address to, uint256 amount);
    
    modifier onlyRegistered() {
        require(registeredUsers[msg.sender], "Usuario no registrado");
        _;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Solo el propietario puede ejecutar esta funcion");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    // Registrar usuario
    function register() external {
        registeredUsers[msg.sender] = true;
        emit UserRegistered(msg.sender);
    }
    
    // Depositar ETH
    function deposit() external payable onlyRegistered {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
    
    // Transferir ETH a otro usuario registrado
    function transfer(address _to, uint256 _amount) external onlyRegistered {
        require(registeredUsers[_to], "Destinatario no registrado");
        require(balances[msg.sender] >= _amount, "Saldo insuficiente");
        
        balances[msg.sender] -= _amount;
        balances[_to] += _amount;
        
        emit Transfer(msg.sender, _to, _amount);
    }
    
    // Retirar ETH
    function withdraw(uint256 _amount) external onlyRegistered {
        require(balances[msg.sender] >= _amount, "Saldo insuficiente");
        
        balances[msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);
    }
    
    // Ver saldo
    function getBalance() external view returns (uint256) {
        return balances[msg.sender];
    }
    
    // Retirar comisiones del contrato (solo owner)
    function withdrawFees() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    // Recibir ETH
    receive() external payable {
        if (registeredUsers[msg.sender]) {
            balances[msg.sender] += msg.value;
            emit Deposit(msg.sender, msg.value);
        }
    }
}