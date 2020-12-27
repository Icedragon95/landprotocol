### Steps to create a new smart contract project


```bash
# You'll only need to run this once or when new test data is added
mkdir MySmartContract && cd $_

truffle init

truffle create contract HelloWorldContract

# generate the migration file.
truffle create migration deploy_my_contract

# Turns your Solidity code to bytecode
truffle compile

# Migrate the bytecode into your development environment
truffle migrate — network development

truffle migrate --network kovan

# recompile and re-deploy after changing code
truffle migrate — reset

# Communicate with your smart contract via the Truffle CLI
truffle console — network development

```


``` 
	# set two variables, hello and sign, for your smart contracts so that you can interact with them.
	truffle(development)> HelloWorldContract.deployed().then(_app => { hello = _app })
	truffle(development)> MD5SmartContract.deployed().then(_app => { doc = _app })

	hello.greet()
	
```