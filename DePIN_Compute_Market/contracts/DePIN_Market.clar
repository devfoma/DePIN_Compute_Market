;; DePIN Compute Market - Decentralized AI Training Infrastructure
;; Addressing the $500B AI investment surge and need for decentralized compute
;; Marketplace for trading GPU compute power for AI model training

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-invalid-provider (err u500))
(define-constant err-insufficient-compute (err u501))
(define-constant err-job-not-found (err u502))
(define-constant err-already-claimed (err u503))
(define-constant err-invalid-proof (err u504))
(define-constant err-provider-offline (err u505))
(define-constant err-invalid-gpu (err u506))
(define-constant err-job-active (err u507))

;; Market parameters
(define-constant min-gpu-memory u8) ;; 8GB minimum
(define-constant platform-fee u250) ;; 2.5%
(define-constant verification-threshold u3) ;; 3 validators needed
(define-constant uptime-requirement u95) ;; 95% uptime required

;; GPU tiers
(define-constant GPU_CONSUMER u1) ;; RTX 4090 level
(define-constant GPU_PROSUMER u2) ;; A6000 level  
(define-constant GPU_DATACENTER u3) ;; H100 level

;; Data Variables
(define-data-var total-compute-hours uint u0)
(define-data-var active-providers uint u0)
(define-data-var jobs-completed uint u0)
(define-data-var total-gpu-hours-sold uint u0)

;; Maps
(define-map compute-providers
    principal
    {
        gpu-count: uint,
        gpu-tier: uint,
        total-memory: uint, ;; in GB
        hourly-rate: uint, ;; in microSTX
        availability: uint, ;; percentage 0-100
        reputation-score: uint,
        total-jobs: uint,
        location-hash: (buff 32),
        is-verified: bool,
        last-heartbeat: uint
    }
)

(define-map training-jobs
    uint ;; job-id
    {
        client: principal,
        model-hash: (buff 32),
        dataset-size: uint, ;; in GB
        gpu-hours-needed: uint,
        gpu-tier-required: uint,
        budget: uint,
        providers: (list 10 principal),
        start-block: uint,
        end-block: uint,
        status: (string-ascii 10),
        result-hash: (buff 32)
    }
)

(define-map job-assignments
    {job-id: uint, provider: principal}
    {
        gpu-hours-assigned: uint,
        work-proof: (buff 256),
        completed: bool,
        validated: bool,
        earnings: uint
    }
)

(define-map compute-validations
    {job-id: uint, validator: principal}
    {
        is-valid: bool,
        validation-proof: (buff 128),
        timestamp: uint
    }
)

(define-map provider-metrics
    principal
    {
        total-gpu-hours: uint,
        total-earnings: uint,
        failed-jobs: uint,
        average-performance: uint, ;; TFLOPS
        carbon-credits: uint
    }
)

;; Read-only functions
(define-read-only (get-provider-info (provider principal))
    (map-get? compute-providers provider)
)

(define-read-only (get-job-details (job-id uint))
    (map-get? training-jobs job-id)
)

(define-read-only (calculate-job-cost (gpu-hours uint) (gpu-tier uint))
    (let (
        (base-rate (if (is-eq gpu-tier GPU_DATACENTER) u1000000
                      (if (is-eq gpu-tier GPU_PROSUMER) u500000
                          u250000))) ;; microSTX per hour
    )
        (* gpu-hours base-rate)
    )
)

(define-read-only (get-market-stats)
    {
        total-compute-hours: (var-get total-compute-hours),
        active-providers: (var-get active-providers),
        jobs-completed: (var-get jobs-completed),
        average-gpu-utilization: (calculate-market-utilization)
    }
)

;; Public functions

;; Register as compute provider
(define-public (register-provider
    (gpu-count uint)
    (gpu-tier uint)
    (total-memory uint)
    (hourly-rate uint)
    (location-hash (buff 32)))
    (begin
        (asserts! (>= total-memory (* gpu-count min-gpu-memory)) err-invalid-gpu)
        (asserts! (and (>= gpu-tier GPU_CONSUMER) (<= gpu-tier GPU_DATACENTER)) err-invalid-gpu)
        (asserts! (> hourly-rate u0) err-invalid-provider)
        
        (map-set compute-providers tx-sender {
            gpu-count: gpu-count,
            gpu-tier: gpu-tier,
            total-memory: total-memory,
            hourly-rate: hourly-rate,
            availability: u100,
            reputation-score: u50,
            total-jobs: u0,
            location-hash: location-hash,
            is-verified: false,
            last-heartbeat: stacks-block-height
        })
        
        (var-set active-providers (+ (var-get active-providers) u1))
        
        (ok true)
    )
)

;; Submit AI training job
(define-public (submit-training-job
    (model-hash (buff 32))
    (dataset-size uint)
    (gpu-hours-needed uint)
    (gpu-tier-required uint)
    (budget uint))
    (let (
        (job-id (+ (var-get jobs-completed) u1))
        (estimated-cost (calculate-job-cost gpu-hours-needed gpu-tier-required))
    )
        (asserts! (>= budget estimated-cost) err-insufficient-compute)
        
        ;; Lock budget
        (try! (stx-transfer? budget tx-sender (as-contract tx-sender)))
        
        (map-set training-jobs job-id {
            client: tx-sender,
            model-hash: model-hash,
            dataset-size: dataset-size,
            gpu-hours-needed: gpu-hours-needed,
            gpu-tier-required: gpu-tier-required,
            budget: budget,
            providers: (list),
            start-block: stacks-block-height,
            end-block: u0,
            status: "pending",
            result-hash: 0x00
        })
        
        (ok job-id)
    )
)

;; Provider accepts job
(define-public (accept-job
    (job-id uint)
    (gpu-hours-offered uint))
    (let (
        (job (unwrap! (map-get? training-jobs job-id) err-job-not-found))
        (provider (unwrap! (map-get? compute-providers tx-sender) err-invalid-provider))
    )
        (asserts! (is-eq (get status job) "pending") err-job-active)
        (asserts! (>= (get gpu-tier provider) (get gpu-tier-required job)) err-invalid-gpu)
        (asserts! (>= (get availability provider) uptime-requirement) err-provider-offline)
        
        ;; Assign work to provider
        (map-set job-assignments {job-id: job-id, provider: tx-sender} {
            gpu-hours-assigned: gpu-hours-offered,
            work-proof: 0x00,
            completed: false,
            validated: false,
            earnings: u0
        })
        
        ;; Update job with provider
        (let (
            (current-providers (get providers job))
        )
            (map-set training-jobs job-id (merge job {
                providers: (unwrap! (as-max-len? (append current-providers tx-sender) u10) err-invalid-provider),
                status: "active"
            }))
        )
        
        (ok gpu-hours-offered)
    )
)

;; Submit work proof
(define-public (submit-work-proof
    (job-id uint)
    (work-proof (buff 256))
    (result-hash (buff 32)))
    (let (
        (job (unwrap! (map-get? training-jobs job-id) err-job-not-found))
        (assignment (unwrap! (map-get? job-assignments {job-id: job-id, provider: tx-sender}) err-invalid-provider))
    )
        (asserts! (is-eq (get status job) "active") err-job-not-found)
        (asserts! (not (get completed assignment)) err-already-claimed)
        
        ;; Update assignment with proof
        (map-set job-assignments {job-id: job-id, provider: tx-sender} (merge assignment {
            work-proof: work-proof,
            completed: true
        }))
        
        ;; Update job result
        (map-set training-jobs job-id (merge job {
            result-hash: result-hash,
            end-block: stacks-block-height
        }))
        
        ;; Update provider metrics
        (update-provider-metrics tx-sender (get gpu-hours-assigned assignment))
        
        (ok true)
    )
)

;; Validate completed work
(define-public (validate-work
    (job-id uint)
    (provider principal)
    (is-valid bool)
    (validation-proof (buff 128)))
    (let (
        (job (unwrap! (map-get? training-jobs job-id) err-job-not-found))
        (validator-info (unwrap! (map-get? compute-providers tx-sender) err-invalid-provider))
    )
        ;; Only verified providers can validate
        (asserts! (get is-verified validator-info) err-invalid-provider)
        (asserts! (>= (get reputation-score validator-info) u80) err-invalid-provider)
        
        (map-set compute-validations {job-id: job-id, validator: tx-sender} {
            is-valid: is-valid,
            validation-proof: validation-proof,
            timestamp: stacks-block-height
        })
        
        ;; Check if enough validations
        (let (
            (validation-count (count-validations job-id))
        )
            (if (>= validation-count verification-threshold)
                (finalize-job job-id)
                (ok false))
        )
    )
)

;; Claim earnings from completed job
(define-public (claim-earnings (job-id uint))
    (let (
        (job (unwrap! (map-get? training-jobs job-id) err-job-not-found))
        (assignment (unwrap! (map-get? job-assignments {job-id: job-id, provider: tx-sender}) err-invalid-provider))
    )
        (asserts! (get completed assignment) err-job-active)
        (asserts! (get validated assignment) err-invalid-proof)
        (asserts! (> (get earnings assignment) u0) err-already-claimed)
        
        (let (
            (payout (get earnings assignment))
            (platform-cut (/ (* payout platform-fee) u10000))
            (provider-earning (- payout platform-cut))
        )
            ;; Transfer earnings
            (try! (as-contract (stx-transfer? provider-earning tx-sender tx-sender)))
            
            ;; Mark as claimed
            (map-set job-assignments {job-id: job-id, provider: tx-sender} (merge assignment {
                earnings: u0
            }))
            
            ;; Update metrics
            (let (
                (metrics (default-to 
                    {total-gpu-hours: u0, total-earnings: u0, failed-jobs: u0, 
                     average-performance: u0, carbon-credits: u0}
                    (map-get? provider-metrics tx-sender)))
            )
                (map-set provider-metrics tx-sender (merge metrics {
                    total-earnings: (+ (get total-earnings metrics) provider-earning)
                }))
            )
            
            (ok provider-earning)
        )
    )
)

;; Provider heartbeat
(define-public (provider-heartbeat (availability uint))
    (let (
        (provider (unwrap! (map-get? compute-providers tx-sender) err-invalid-provider))
    )
        (map-set compute-providers tx-sender (merge provider {
            availability: availability,
            last-heartbeat: stacks-block-height
        }))
        
        (ok true)
    )
)

;; Private functions
(define-private (calculate-market-utilization)
    ;; Simplified calculation
    (if (> (var-get active-providers) u0)
        (/ (* (var-get total-gpu-hours-sold) u100) 
           (* (var-get active-providers) u24 u30)) ;; Assuming 24/7 operation
        u0)
)

(define-private (count-validations (job-id uint))
    ;; This would count actual validations in a real implementation
    u3
)

(define-private (finalize-job (job-id uint))
    (let (
        (job (unwrap! (map-get? training-jobs job-id) err-job-not-found))
    )
        ;; Calculate and distribute payments to providers
        (map-set training-jobs job-id (merge job {
            status: "completed"
        }))
        
        (var-set jobs-completed (+ (var-get jobs-completed) u1))
        
        (ok true)
    )
)

(define-private (update-provider-metrics (provider principal) (gpu-hours uint))
    (let (
        (metrics (default-to 
            {total-gpu-hours: u0, total-earnings: u0, failed-jobs: u0, 
             average-performance: u0, carbon-credits: u0}
            (map-get? provider-metrics provider)))
    )
        (map-set provider-metrics provider (merge metrics {
            total-gpu-hours: (+ (get total-gpu-hours metrics) gpu-hours)
        }))
        
        (var-set total-gpu-hours-sold (+ (var-get total-gpu-hours-sold) gpu-hours))
    )
)