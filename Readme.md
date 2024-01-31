# Readme

### 1. Copy env file
```bash
cp .env.example .env
```

### 2. Install dependencies
```bash
./run.sh
```


### 3. build litecoin
```bash
docker build -f Dockerfile.litecoin_core -t litecoin_core .
```