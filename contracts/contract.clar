;; Decentralized Study Timer Contract
;; A blockchain-based study session tracking system for educational accountability and progress monitoring

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-unauthorized (err u101))
(define-constant err-invalid-session (err u102))
(define-constant err-session-not-found (err u103))
(define-constant err-session-already-ended (err u104))

;; Data structures
(define-map study-sessions
  {user: principal, session-id: uint}
  {
    subject: (string-ascii 50),
    start-time: uint,
    end-time: (optional uint),
    duration-minutes: uint,
    is-completed: bool,
    notes: (string-ascii 200)
  })

(define-map user-stats
  principal
  {
    total-sessions: uint,
    total-study-minutes: uint,
    current-streak: uint,
    longest-streak: uint,
    last-study-date: uint,
    session-counter: uint
  })

;; Global tracking
(define-data-var total-users uint u0)
(define-data-var total-study-minutes uint u0)

;; Function 1: Start Study Session
;; Allows users to begin a new study session with subject and optional notes
(define-public (start-study-session (subject (string-ascii 50)) (notes (string-ascii 200)))
  (let (
    (user tx-sender)
    (current-time block-height)
    (user-data (default-to 
      {total-sessions: u0, total-study-minutes: u0, current-streak: u0, 
       longest-streak: u0, last-study-date: u0, session-counter: u0}
      (map-get? user-stats user)))
    (session-id (+ (get session-counter user-data) u1))
  )
    ;; Validate input
    (asserts! (> (len subject) u0) err-invalid-session)
    
    ;; Create new study session
    (map-set study-sessions
      {user: user, session-id: session-id}
      {
        subject: subject,
        start-time: current-time,
        end-time: none,
        duration-minutes: u0,
        is-completed: false,
        notes: notes
      })
    
    ;; Update user stats - increment session counter
    (map-set user-stats user
      (merge user-data {session-counter: session-id}))
    
    ;; If first-time user, increment total users
    (if (is-eq (get total-sessions user-data) u0)
      (var-set total-users (+ (var-get total-users) u1))
      true)
    
    (ok {session-id: session-id, message: "Study session started successfully"})))

;; Function 2: End Study Session
;; Allows users to complete their study session and calculate study time
(define-public (end-study-session (session-id uint))
  (let (
    (user tx-sender)
    (current-time block-height)
    (session-key {user: user, session-id: session-id})
    (session-data (map-get? study-sessions session-key))
    (user-data (default-to 
      {total-sessions: u0, total-study-minutes: u0, current-streak: u0, 
       longest-streak: u0, last-study-date: u0, session-counter: u0}
      (map-get? user-stats user)))
  )
    ;; Validate session exists
    (asserts! (is-some session-data) err-session-not-found)
    
    (let (
      (session (unwrap-panic session-data))
      (start-time (get start-time session))
      (study-duration (- current-time start-time))
      (is-same-day (is-eq (get last-study-date user-data) current-time))
      (new-streak (if is-same-day 
                    (get current-streak user-data)
                    (+ (get current-streak user-data) u1)))
      (max-streak (if (> new-streak (get longest-streak user-data))
                    new-streak
                    (get longest-streak user-data)))
    )
      ;; Validate session not already ended
      (asserts! (not (get is-completed session)) err-session-already-ended)
      
      ;; Update session with end time and completion
      (map-set study-sessions session-key
        (merge session {
          end-time: (some current-time),
          duration-minutes: study-duration,
          is-completed: true
        }))
      
      ;; Update user statistics
      (map-set user-stats user {
        total-sessions: (+ (get total-sessions user-data) u1),
        total-study-minutes: (+ (get total-study-minutes user-data) study-duration),
        current-streak: new-streak,
        longest-streak: max-streak,
        last-study-date: current-time,
        session-counter: (get session-counter user-data)
      })
      
      ;; Update global study minutes
      (var-set total-study-minutes (+ (var-get total-study-minutes) study-duration))
      
      (ok {
        session-id: session-id,
        duration-minutes: study-duration,
        current-streak: new-streak,
        message: "Study session completed successfully"
      }))))

;; Read-only functions for data retrieval
(define-read-only (get-study-session (user principal) (session-id uint))
  (map-get? study-sessions {user: user, session-id: session-id}))

(define-read-only (get-user-stats (user principal))
  (map-get? user-stats user))

(define-read-only (get-global-stats)
  (ok {
    total-users: (var-get total-users),
    total-study-minutes: (var-get total-study-minutes),
    average-study-time: (if (> (var-get total-users) u0)
                          (/ (var-get total-study-minutes) (var-get total-users))
                          u0)
  }))

(define-read-only (get-contract-info)
  (ok {
    owner: contract-owner,
    name: "Decentralized Study Timer",
    version: "1.0.0"
  }))