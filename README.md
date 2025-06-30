# DePIN Compute Market

A **decentralized marketplace** for trading GPU compute power specifically designed for AI model training, built on the Stacks blockchain using Clarity smart contracts.

---

## 🌐 Overview

The **DePIN Compute Market** addresses the growing demand for decentralized and scalable compute infrastructure to support AI development, especially amidst the \$500B+ surge in AI investments. This smart contract facilitates trustless coordination between compute providers and AI model developers.

---

## 💡 Features

* **Provider Registration**: GPU compute providers can register and list their available compute resources.
* **Job Posting**: Users can post training jobs with specific compute requirements.
* **Resource Matching**: The contract matches jobs to suitable compute providers based on GPU specs, uptime, and availability.
* **Proof-of-Compute Verification**: Jobs are validated using a threshold of independent validators.
* **Incentive & Penalty System**: Rewards for verified jobs, penalties for downtime or invalid proofs.
* **Tiered GPUs**: Recognizes different GPU capabilities (e.g., consumer, prosumer, datacenter-level).

---

## 🛠 Configuration & Constants

* **Minimum GPU Memory**: 8GB
* **Platform Fee**: 2.5%
* **Verification Threshold**: 3 validators
* **Uptime Requirement**: 95%
* **GPU Tiers**:

  * `GPU_CONSUMER` (e.g., RTX 4090)
  * `GPU_PROSUMER`
  * `GPU_DATACENTER`

---

## 📦 Key Functions (from smart contract)

* `register-provider`: Register a compute provider.
* `post-job`: Submit a job request with compute specs.
* `match-job`: Match job with provider.
* `submit-proof`: Submit completion and proof of job execution.
* `verify-proof`: Validators verify compute was correctly executed.
* `claim-reward`: Provider claims reward after successful job validation.

---

## ❗ Error Codes

* `err-invalid-provider (500)`
* `err-insufficient-compute (501)`
* `err-job-not-found (502)`
* `err-already-claimed (503)`
* `err-invalid-proof (504)`
* `err-provider-offline (505)`
* `err-invalid-gpu (506)`
* `err-job-active (507)`

---

## 🛡 Security & Trust

* On-chain matching and validation reduce fraud.
* Validator-based verification ensures correctness.
* All participants are incentivized to act honestly through Clarity's deterministic logic.

---

## 🧩 Future Work

* Integration with off-chain GPU monitoring oracles.
* DAO-based governance for platform fees and parameters.
* Dynamic pricing models for compute rates.

---

## 📄 License

This project is licensed under the MIT License.
