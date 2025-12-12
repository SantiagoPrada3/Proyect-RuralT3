// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title PagoRural
 * @dev Contrato inteligente para gestionar pagos rurales
 * @notice Este contrato permite realizar transferencias, consultar balances y ver historial de transacciones
 */
contract PagoRural {
    
    // ============ ESTRUCTURAS ============
    
    struct Transaction {
        address from;
        address to;
        uint256 amount;
        uint256 timestamp;
        string description;
        TransactionStatus status;
    }
    
    struct User {
        string name;
        string phone;
        bool isRegistered;
        uint256 registrationDate;
    }
    
    // ============ ENUMS ============
    
    enum TransactionStatus {
        Pending,
        Completed,
        Cancelled
    }
    
    // ============ VARIABLES DE ESTADO ============
    
    address public owner;
    uint256 public transactionFee; // Fee en wei (ejemplo: 1000 = 0.000000000000001 ETH)
    uint256 public totalTransactions;
    
    mapping(address => User) public users;
    mapping(address => uint256) public balances;
    mapping(address => Transaction[]) public userTransactions;
    mapping(uint256 => Transaction) public allTransactions;
    
    address[] public registeredUsers;
    
    // ============ EVENTOS ============
    
    event UserRegistered(address indexed userAddress, string name, uint256 timestamp);
    event PaymentSent(address indexed from, address indexed to, uint256 amount, uint256 timestamp);
    event PaymentReceived(address indexed from, address indexed to, uint256 amount, uint256 timestamp);
    event Deposit(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawal(address indexed user, uint256 amount, uint256 timestamp);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    
    // ============ MODIFICADORES ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Solo el propietario puede ejecutar esta funcion");
        _;
    }
    
    modifier onlyRegistered() {
        require(users[msg.sender].isRegistered, "Usuario no registrado");
        _;
    }
    
    modifier validAddress(address _addr) {
        require(_addr != address(0), "Direccion invalida");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(uint256 _initialFee) {
        owner = msg.sender;
        transactionFee = _initialFee;
    }
    
    // ============ FUNCIONES DE USUARIO ============
    
    /**
     * @dev Registra un nuevo usuario en el sistema
     * @param _name Nombre del usuario
     * @param _phone Teléfono del usuario
     */
    function registerUser(string memory _name, string memory _phone) external {
        require(!users[msg.sender].isRegistered, "Usuario ya registrado");
        require(bytes(_name).length > 0, "El nombre no puede estar vacio");
        
        users[msg.sender] = User({
            name: _name,
            phone: _phone,
            isRegistered: true,
            registrationDate: block.timestamp
        });
        
        registeredUsers.push(msg.sender);
        
        emit UserRegistered(msg.sender, _name, block.timestamp);
    }
    
    /**
     * @dev Actualiza la información del usuario
     * @param _name Nuevo nombre
     * @param _phone Nuevo teléfono
     */
    function updateUserInfo(string memory _name, string memory _phone) external onlyRegistered {
        require(bytes(_name).length > 0, "El nombre no puede estar vacio");
        
        users[msg.sender].name = _name;
        users[msg.sender].phone = _phone;
    }
    
    // ============ FUNCIONES DE BALANCE ============
    
    /**
     * @dev Deposita ETH en la cuenta del usuario
     */
    function deposit() external payable onlyRegistered {
        require(msg.value > 0, "El monto debe ser mayor a 0");
        
        balances[msg.sender] += msg.value;
        
        emit Deposit(msg.sender, msg.value, block.timestamp);
    }
    
    /**
     * @dev Retira ETH de la cuenta del usuario
     * @param _amount Cantidad a retirar en wei
     */
    function withdraw(uint256 _amount) external onlyRegistered {
        require(_amount > 0, "El monto debe ser mayor a 0");
        require(balances[msg.sender] >= _amount, "Balance insuficiente");
        
        balances[msg.sender] -= _amount;
        
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Error al transferir ETH");
        
        emit Withdrawal(msg.sender, _amount, block.timestamp);
    }
    
    /**
     * @dev Consulta el balance del usuario
     * @return Balance en wei
     */
    function getBalance() external view returns (uint256) {
        return balances[msg.sender];
    }
    
    // ============ FUNCIONES DE PAGO ============
    
    /**
     * @dev Realiza un pago a otro usuario
     * @param _to Dirección del destinatario
     * @param _amount Cantidad a enviar en wei
     * @param _description Descripción del pago
     */
    function pay(
        address _to, 
        uint256 _amount, 
        string memory _description
    ) external onlyRegistered validAddress(_to) {
        require(_to != msg.sender, "No puedes enviarte dinero a ti mismo");
        require(_amount > 0, "El monto debe ser mayor a 0");
        require(users[_to].isRegistered, "El destinatario no esta registrado");
        
        uint256 totalAmount = _amount + transactionFee;
        require(balances[msg.sender] >= totalAmount, "Balance insuficiente para cubrir el pago y la comision");
        
        // Actualizar balances
        balances[msg.sender] -= totalAmount;
        balances[_to] += _amount;
        balances[owner] += transactionFee; // Fee para el owner
        
        // Crear transacción
        Transaction memory newTransaction = Transaction({
            from: msg.sender,
            to: _to,
            amount: _amount,
            timestamp: block.timestamp,
            description: _description,
            status: TransactionStatus.Completed
        });
        
        // Guardar transacción
        allTransactions[totalTransactions] = newTransaction;
        userTransactions[msg.sender].push(newTransaction);
        userTransactions[_to].push(newTransaction);
        totalTransactions++;
        
        emit PaymentSent(msg.sender, _to, _amount, block.timestamp);
        emit PaymentReceived(msg.sender, _to, _amount, block.timestamp);
    }
    
    /**
     * @dev Pago directo con ETH (sin usar balance interno)
     * @param _to Dirección del destinatario
     * @param _description Descripción del pago
     */
    function payDirect(
        address _to, 
        string memory _description
    ) external payable onlyRegistered validAddress(_to) {
        require(_to != msg.sender, "No puedes enviarte dinero a ti mismo");
        require(msg.value > transactionFee, "El monto debe ser mayor a la comision");
        require(users[_to].isRegistered, "El destinatario no esta registrado");
        
        uint256 paymentAmount = msg.value - transactionFee;
        
        // Actualizar balances
        balances[_to] += paymentAmount;
        balances[owner] += transactionFee;
        
        // Crear transacción
        Transaction memory newTransaction = Transaction({
            from: msg.sender,
            to: _to,
            amount: paymentAmount,
            timestamp: block.timestamp,
            description: _description,
            status: TransactionStatus.Completed
        });
        
        // Guardar transacción
        allTransactions[totalTransactions] = newTransaction;
        userTransactions[msg.sender].push(newTransaction);
        userTransactions[_to].push(newTransaction);
        totalTransactions++;
        
        emit PaymentSent(msg.sender, _to, paymentAmount, block.timestamp);
        emit PaymentReceived(msg.sender, _to, paymentAmount, block.timestamp);
    }
    
    // ============ FUNCIONES DE HISTORIAL ============
    
    /**
     * @dev Obtiene el historial de transacciones del usuario
     * @return Array de transacciones
     */
    function getMyTransactions() external view onlyRegistered returns (Transaction[] memory) {
        return userTransactions[msg.sender];
    }
    
    /**
     * @dev Obtiene el número de transacciones del usuario
     * @return Número de transacciones
     */
    function getMyTransactionCount() external view returns (uint256) {
        return userTransactions[msg.sender].length;
    }
    
    /**
     * @dev Obtiene una transacción específica por índice
     * @param _index Índice de la transacción
     * @return Transacción
     */
    function getTransactionById(uint256 _index) external view returns (Transaction memory) {
        require(_index < totalTransactions, "Indice de transaccion invalido");
        return allTransactions[_index];
    }
    
    // ============ FUNCIONES DE CONSULTA ============
    
    /**
     * @dev Verifica si un usuario está registrado
     * @param _user Dirección del usuario
     * @return true si está registrado
     */
    function isUserRegistered(address _user) external view returns (bool) {
        return users[_user].isRegistered;
    }
    
    /**
     * @dev Obtiene la información de un usuario
     * @param _user Dirección del usuario
     * @return User información del usuario
     */
    function getUserInfo(address _user) external view returns (User memory) {
        require(users[_user].isRegistered, "Usuario no registrado");
        return users[_user];
    }
    
    /**
     * @dev Obtiene el número total de usuarios registrados
     * @return Número de usuarios
     */
    function getTotalUsers() external view returns (uint256) {
        return registeredUsers.length;
    }
    
    // ============ FUNCIONES DE ADMINISTRADOR ============
    
    /**
     * @dev Actualiza la comisión por transacción
     * @param _newFee Nueva comisión en wei
     */
    function setTransactionFee(uint256 _newFee) external onlyOwner {
        uint256 oldFee = transactionFee;
        transactionFee = _newFee;
        emit FeeUpdated(oldFee, _newFee);
    }
    
    /**
     * @dev Transfiere la propiedad del contrato
     * @param _newOwner Nueva dirección del propietario
     */
    function transferOwnership(address _newOwner) external onlyOwner validAddress(_newOwner) {
        owner = _newOwner;
    }
    
    /**
     * @dev Retira las comisiones acumuladas (solo owner)
     */
    function withdrawFees() external onlyOwner {
        uint256 ownerBalance = balances[owner];
        require(ownerBalance > 0, "No hay comisiones para retirar");
        
        balances[owner] = 0;
        
        (bool success, ) = payable(owner).call{value: ownerBalance}("");
        require(success, "Error al transferir comisiones");
    }
    
    // ============ FUNCIONES FALLBACK ============
    
    receive() external payable {
        if (users[msg.sender].isRegistered) {
            balances[msg.sender] += msg.value;
            emit Deposit(msg.sender, msg.value, block.timestamp);
        }
    }
    
    fallback() external payable {
        revert("Funcion no reconocida");
    }
}
