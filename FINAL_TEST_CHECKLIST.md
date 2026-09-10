# SafeWalk Final Manual Test Checklist

Use this checklist against the feature-frozen release candidate. Run the full suite once on Simulator and all marked device scenarios on a physical iPhone. Record the build commit, device, OS version, network state, and tester before starting.

**Build/commit:** ____________________  
**Device and OS:** ____________________  
**Tester/date:** ____________________

For termination tests, stop the process from Xcode or the app switcher; do not uninstall the app unless the test says to. For timing tests, the current periodic interval is 60 seconds and each safety response window is 30 seconds.

## First launch

### FL-01 — Fresh installation

- **Purpose:** Verify the app starts with no stale local state.
- **Preconditions/setup:** Delete SafeWalk from the device or Simulator, then install the current build.
- **Exact steps:**
  1. Launch SafeWalk.
  2. Wait for the home screen to settle.
  3. Inspect the available cards and actions.
- **Expected result:** The home screen shows **Choose Destination**, **Emergency Contact**, and **Journey History**. No Resume or completion card appears. No crash or emergency state appears.
- [ ] Pass  - [ ] Fail

### FL-02 — Initial UI on a small display

- **Purpose:** Confirm primary content remains reachable on a compact screen.
- **Preconditions/setup:** Use a small supported Simulator and default text size.
- **Exact steps:**
  1. Launch the app.
  2. Scroll from the top to the bottom.
  3. Open and return from each home navigation link.
- **Expected result:** Text and buttons are not clipped, all cards can be reached by scrolling, and back navigation works.
- [ ] Pass  - [ ] Fail

## Permissions

### PM-01 — Allow foreground location

- **Purpose:** Verify the normal initial location authorization path.
- **Preconditions/setup:** Reset location privacy for SafeWalk; enable system Location Services.
- **Exact steps:**
  1. Choose and select a destination.
  2. Continue to route planning when prompted.
  3. Choose **Allow While Using App**.
- **Expected result:** SafeWalk obtains a current location, calculates a route, and does not immediately repeat the permission prompt.
- [ ] Pass  - [ ] Fail

### PM-02 — Deny location

- **Purpose:** Verify denial is actionable and safe.
- **Preconditions/setup:** Reset location privacy for SafeWalk.
- **Exact steps:**
  1. Navigate to a selected destination.
  2. Deny the location request.
  3. Try the visible recovery/settings action.
- **Expected result:** No route or journey starts. The UI explains that location access is disabled and offers a route to Settings where appropriate. No repeated system prompt loop occurs.
- [ ] Pass  - [ ] Fail

### PM-03 — System Location Services disabled

- **Purpose:** Verify the global services-off state.
- **Preconditions/setup:** Turn off Location Services in system privacy settings.
- **Exact steps:**
  1. Launch SafeWalk and select a destination.
  2. Attempt to prepare the route.
  3. Return to the app after checking Settings.
- **Expected result:** SafeWalk states that Location Services are disabled, does not enter active tracking, and remains responsive.
- [ ] Pass  - [ ] Fail

### PM-04 — Notification authorization

- **Purpose:** Verify local notification permission and status handling.
- **Preconditions/setup:** Reset notification permission for SafeWalk.
- **Exact steps:**
  1. Start a journey and respond to the notification prompt when presented.
  2. Allow alerts and sounds.
  3. Background the app and trigger a check-in.
- **Expected result:** Permission is requested once through the system UI and the check-in notification is delivered with SafeWalk actions.
- [ ] Pass  - [ ] Fail

### PM-05 — Notification denied

- **Purpose:** Ensure the safety UI remains usable without notifications.
- **Preconditions/setup:** Deny SafeWalk notifications in Settings.
- **Exact steps:**
  1. Start a journey.
  2. Wait for a periodic check-in or trigger an off-route event.
  3. Return to the foreground.
- **Expected result:** The in-app check-in still appears and can be resolved. The app does not crash or claim that a banner was delivered.
- [ ] Pass  - [ ] Fail

### PM-06 — Background location authorization

- **Purpose:** Verify the When In Use to Always upgrade path.
- **Preconditions/setup:** Physical iPhone preferred; SafeWalk currently has When In Use access.
- **Exact steps:**
  1. Start a journey.
  2. Use the app's background-location permission action if shown.
  3. Select **Always Allow** when iOS offers it.
  4. Background the app while moving or using an Xcode location simulation.
- **Expected result:** SafeWalk does not request Always before obtaining normal access. With Always granted, active-journey location updates can continue in the background and stop after the journey ends.
- [ ] Pass  - [ ] Fail

### PM-07 — Precise Location disabled

- **Purpose:** Verify reduced-accuracy handling.
- **Preconditions/setup:** In Settings, allow location but turn **Precise Location** off.
- **Exact steps:**
  1. Relaunch SafeWalk.
  2. Select a destination and attempt route preparation.
  3. Observe any accuracy guidance and route behavior.
- **Expected result:** The app reports reduced precision where relevant, remains stable, and does not create false arrival/off-route events from rejected low-quality readings.
- [ ] Pass  - [ ] Fail

## Destination search

### DS-01 — Search and selection

- **Purpose:** Verify the complete destination selection path.
- **Preconditions/setup:** Network available; location permission allowed.
- **Exact steps:**
  1. Tap **Choose Destination**.
  2. Enter a nearby place or full address.
  3. Submit the search.
  4. Select one result.
  5. Tap **Plan SafeWalk**.
- **Expected result:** Up to ten relevant results appear, the selected result is visually identified, and route planning opens for that destination.
- [ ] Pass  - [ ] Fail

### DS-02 — Empty and whitespace search

- **Purpose:** Verify query validation.
- **Preconditions/setup:** Destination search screen open.
- **Exact steps:**
  1. Submit an empty query.
  2. Submit a query containing only spaces.
- **Expected result:** No search runs. The app asks for a destination and does not expose an inappropriate retry action.
- [ ] Pass  - [ ] Fail

### DS-03 — Rapid replacement and clear

- **Purpose:** Verify cancellation and stale-result protection.
- **Preconditions/setup:** Network available.
- **Exact steps:**
  1. Submit one broad search.
  2. Immediately replace it with a different search and submit.
  3. Tap the clear-search control while results are loading.
- **Expected result:** Old results do not overwrite the latest query, clear empties the query/results as designed, and no crash occurs.
- [ ] Pass  - [ ] Fail

### DS-04 — Search failure and retry

- **Purpose:** Verify network error recovery.
- **Preconditions/setup:** Destination search open; disable networking before submission.
- **Exact steps:**
  1. Submit a valid place name while offline.
  2. Read the error state.
  3. Restore networking.
  4. Tap **Retry Search**.
- **Expected result:** A useful error appears, retry is enabled for the last valid query, and results load after connectivity returns.
- [ ] Pass  - [ ] Fail

## Routing

### RT-01 — Walking route loading

- **Purpose:** Verify initial MapKit routing and rendering.
- **Preconditions/setup:** Valid current location, selected destination, network available.
- **Exact steps:**
  1. Open route planning from a selected search result.
  2. Wait for calculation to finish.
  3. Inspect the map and route summary.
- **Expected result:** A walking route is displayed, loading ends, planned distance is nonnegative, and **Start SafeWalk** becomes available only when the route is ready.
- [ ] Pass  - [ ] Fail

### RT-02 — Initial route network failure and retry

- **Purpose:** Verify route errors do not leave a broken screen.
- **Preconditions/setup:** Selected destination; disable networking before route calculation.
- **Exact steps:**
  1. Open route planning.
  2. Wait for the route error.
  3. Restore networking.
  4. Tap **Retry Route**.
- **Expected result:** A clear error and retry action appear. Retry loads the route without requiring destination reselection.
- [ ] Pass  - [ ] Fail

## Journey

### JN-01 — Start and active tracking

- **Purpose:** Verify transition from route-ready to active.
- **Preconditions/setup:** Route successfully loaded.
- **Exact steps:**
  1. Tap **Start SafeWalk** once.
  2. Observe the active journey screen and map.
  3. Return to the home screen and inspect its card.
- **Expected result:** One journey starts with the chosen destination, active controls appear, and home shows **Resume SafeWalk** for the same journey.
- [ ] Pass  - [ ] Fail

### JN-02 — Progress updates

- **Purpose:** Verify accepted location movement updates progress without replacing the route.
- **Preconditions/setup:** Active journey; simulated or real movement along the route.
- **Exact steps:**
  1. Note the initial route and remaining distance.
  2. Move along several route points toward the destination.
  3. Compare the map route and progress display.
- **Expected result:** Remaining distance/progress updates sensibly, values do not become negative, and the route remains stable.
- [ ] Pass  - [ ] Fail

### JN-03 — Background then foreground

- **Purpose:** Verify active journey lifecycle handling.
- **Preconditions/setup:** Active journey; background permission configured for the test variant.
- **Exact steps:**
  1. Send SafeWalk to the background for at least 20 seconds.
  2. Continue simulated or physical movement.
  3. Reopen SafeWalk.
- **Expected result:** The same journey returns, state remains coherent, persisted deadlines account for elapsed time, and no duplicate check-in appears.
- [ ] Pass  - [ ] Fail

## Periodic check-in

### PC-01 — Trigger and countdown

- **Purpose:** Verify a periodic cycle creates one check-in.
- **Preconditions/setup:** Active journey with no check-in or emergency state.
- **Exact steps:**
  1. Leave the app active for the 60-second periodic interval.
  2. Observe the check-in when it appears.
  3. Watch several countdown ticks.
- **Expected result:** Exactly one periodic check-in appears with a 30-second countdown that decreases based on its deadline.
- [ ] Pass  - [ ] Fail

### PC-02 — Periodic I'm Safe and next cycle

- **Purpose:** Verify periodic confirmation does not reroute.
- **Preconditions/setup:** Active periodic check-in.
- **Exact steps:**
  1. Note the current route and reroute count.
  2. Tap **I'm Safe**.
  3. Continue observing for another periodic interval.
- **Expected result:** The check-in clears, no reroute begins, the route/count remain unchanged, and one new periodic cycle starts.
- [ ] Pass  - [ ] Fail

## Off route

### OR-01 — Deviation detection and distance

- **Purpose:** Verify segment-based detection and debounce behavior.
- **Preconditions/setup:** Active journey in Simulator with a known route.
- **Exact steps:**
  1. Use Xcode/Simulator location controls to move more than 100 metres away from the route.
  2. Supply at least three accepted location updates at the deviated position.
  3. Observe the distance and safety UI.
- **Expected result:** A single off-route state appears after repeated readings, shows a plausible route distance, and starts one 30-second off-route check-in.
- [ ] Pass  - [ ] Fail

### OR-02 — Off-route notification

- **Purpose:** Verify the background alert for deviation.
- **Preconditions/setup:** Active journey, notifications allowed, app backgrounded.
- **Exact steps:**
  1. Simulate the repeated off-route readings.
  2. Wait for the local notification.
  3. Expand its actions.
- **Expected result:** One route alert appears with **I'm Safe** and **Open SafeWalk** actions and refers to the current journey event.
- [ ] Pass  - [ ] Fail

### OR-03 — Off-route I'm Safe starts reroute

- **Purpose:** Verify reason-aware rerouting.
- **Preconditions/setup:** Active off-route check-in with network available.
- **Exact steps:**
  1. Tap **I'm Safe** in the app.
  2. Observe the reroute loading state and map.
- **Expected result:** The check-in resolves, one reroute request begins, and a successful replacement route becomes both displayed and monitored.
- [ ] Pass  - [ ] Fail

## Rerouting

### RR-01 — Successful replacement and new baseline

- **Purpose:** Verify completion of the reroute transaction.
- **Preconditions/setup:** Active off-route event; network available.
- **Exact steps:**
  1. Confirm safety to begin rerouting.
  2. Wait for success.
  3. Continue along the replacement route.
- **Expected result:** The new route replaces the old one, reroute metadata increments once, progress uses the new route, and another check-in does not start immediately.
- [ ] Pass  - [ ] Fail

### RR-02 — Failed reroute preserves old route

- **Purpose:** Verify navigation context survives a MapKit failure.
- **Preconditions/setup:** Active off-route check-in; disable network immediately before confirming safety.
- **Exact steps:**
  1. Tap **I'm Safe**.
  2. Wait for reroute failure.
  3. Inspect the map and error state.
- **Expected result:** The old route remains visible and monitored, an explanatory error appears, and **Retry Reroute** is available.
- [ ] Pass  - [ ] Fail

### RR-03 — Reroute retry

- **Purpose:** Verify recovery after a failed replacement.
- **Preconditions/setup:** RR-02 failure visible.
- **Exact steps:**
  1. Restore networking.
  2. Tap **Retry Reroute** once.
  3. Wait for MapKit to respond.
- **Expected result:** One replacement request runs, the successful route becomes active, and the failure UI clears.
- [ ] Pass  - [ ] Fail

### RR-04 — End or arrive during reroute

- **Purpose:** Verify late MapKit callbacks cannot restart tracking.
- **Preconditions/setup:** Begin a reroute on a slow or constrained network.
- **Exact steps:**
  1. While rerouting, end the journey; repeat in a separate run by triggering arrival if practical.
  2. Wait long enough for the outstanding request to return.
- **Expected result:** Tracking, check-ins, and location updates stay stopped. No late route appears and no ended/arrived session is resurrected.
- [ ] Pass  - [ ] Fail

## Emergency

### EM-01 — Missed check-in escalation

- **Purpose:** Verify expiry and persisted emergency activation.
- **Preconditions/setup:** Any active check-in.
- **Exact steps:**
  1. Do not press **I'm Safe**.
  2. Wait for the 30-second deadline.
  3. Open emergency options.
- **Expected result:** The check-in becomes expired, emergency state activates, a missed-check-in alert is delivered when permitted, and emergency options remain available.
- [ ] Pass  - [ ] Fail

### EM-02 — Emergency contact action

- **Purpose:** Verify trusted-contact selection and call preparation.
- **Preconditions/setup:** Physical iPhone; save a controlled test contact with a phone number.
- **Exact steps:**
  1. Enter emergency state.
  2. Tap **Call Emergency Contact**.
  3. Cancel at the system confirmation without disturbing a real recipient.
- **Expected result:** SafeWalk targets the saved number through system calling UI and does not expose or call another number automatically.
- [ ] Pass  - [ ] Fail

### EM-03 — Location sharing and SMS composer

- **Purpose:** Verify user-controlled emergency communication.
- **Preconditions/setup:** Physical iPhone preferred; valid current location and saved test contact.
- **Exact steps:**
  1. Open emergency options.
  2. Open **Share Location** and inspect the share content, then cancel.
  3. Open the message action, inspect recipient/body, then cancel.
- **Expected result:** System UI opens with current location context where available. Nothing is sent until the user confirms in the system interface.
- [ ] Pass  - [ ] Fail

## Notifications

### NT-01 — Foreground notification presentation

- **Purpose:** Verify the notification delegate presents alerts while the app is open.
- **Preconditions/setup:** Notifications allowed; active journey in foreground.
- **Exact steps:**
  1. Trigger a periodic or off-route check-in.
  2. Observe the notification presentation.
- **Expected result:** A banner/sound is presented according to system settings and the in-app state matches the notification.
- [ ] Pass  - [ ] Fail

### NT-02 — Background I'm Safe action

- **Purpose:** Verify notification confirmation uses the in-app resolution path.
- **Preconditions/setup:** Current-journey periodic notification visible while app is backgrounded.
- **Exact steps:**
  1. Expand the notification.
  2. Tap **I'm Safe**.
  3. Reopen SafeWalk.
- **Expected result:** The unresolved check-in and emergency state are cleared. A periodic event does not reroute; an off-route event reroutes when runtime tracking is available or after resume.
- [ ] Pass  - [ ] Fail

### NT-03 — Expired notification action

- **Purpose:** Verify **I'm Safe** can resolve the current missed event.
- **Preconditions/setup:** Current journey has reached emergency state and its missed notification is visible.
- **Exact steps:**
  1. Tap **I'm Safe** on the missed notification.
  2. Open the app.
- **Expected result:** The matching unresolved emergency/check-in clears and the current journey remains valid.
- [ ] Pass  - [ ] Fail

### NT-04 — Stale action protection

- **Purpose:** Verify an older journey's notification cannot alter current state.
- **Preconditions/setup:** Retain a delivered notification from journey A, end A, then start journey B.
- **Exact steps:**
  1. Trigger a check-in in journey B.
  2. Use **I'm Safe** on journey A's old notification.
  3. Return to journey B.
- **Expected result:** Journey B's check-in/emergency state is unchanged. No reroute starts and an arrived or ended journey is not modified.
- [ ] Pass  - [ ] Fail

## Force termination and restoration

### TR-01 — Active journey restoration

- **Purpose:** Verify normal cold-launch recovery.
- **Preconditions/setup:** Active journey with no arrival or emergency.
- **Exact steps:**
  1. Force-terminate SafeWalk.
  2. Relaunch it.
  3. Tap **Resume SafeWalk**.
- **Expected result:** Destination and journey metadata restore, a route is recalculated from the current location, and monitoring resumes without creating a history record.
- [ ] Pass  - [ ] Fail

### TR-02 — Active check-in restoration

- **Purpose:** Verify deadline-based countdown recovery.
- **Preconditions/setup:** Active periodic or off-route check-in with more than 10 seconds remaining.
- **Exact steps:**
  1. Note the displayed remaining seconds.
  2. Force-terminate the app for about five seconds.
  3. Relaunch and resume.
- **Expected result:** The same reason restores with time reduced according to the absolute deadline. It does not restart at 30 seconds.
- [ ] Pass  - [ ] Fail

### TR-03 — Check-in expires while terminated

- **Purpose:** Verify missed-deadline restoration.
- **Preconditions/setup:** Active check-in with fewer than 20 seconds remaining.
- **Exact steps:**
  1. Force-terminate SafeWalk.
  2. Wait beyond the stored deadline.
  3. Relaunch and resume.
- **Expected result:** The check-in restores as expired, emergency state is active, and the countdown does not reset.
- [ ] Pass  - [ ] Fail

### TR-04 — Periodic deadline across termination

- **Purpose:** Verify the periodic cycle does not reset on cold launch.
- **Preconditions/setup:** Active journey; note periodic seconds remaining with no active check-in.
- **Exact steps:**
  1. Force-terminate for less than the remaining interval, then relaunch and resume.
  2. Repeat in another journey while waiting beyond the deadline.
- **Expected result:** Before-deadline restoration resumes with elapsed time removed. After-deadline restoration creates one due periodic check-in, not duplicate cycles.
- [ ] Pass  - [ ] Fail

### TR-05 — Emergency state restoration

- **Purpose:** Verify unresolved escalation survives termination.
- **Preconditions/setup:** Current journey in emergency state.
- **Exact steps:**
  1. Force-terminate SafeWalk.
  2. Relaunch and resume the journey.
- **Expected result:** Emergency state and options restore for the same journey until the user confirms safety, arrives, or ends it.
- [ ] Pass  - [ ] Fail

## Arrival

### AR-01 — Arrival threshold and completion screen

- **Purpose:** Verify the active-to-arrived transition.
- **Preconditions/setup:** Active journey; controlled high-quality location simulation or physical approach.
- **Exact steps:**
  1. Move toward the destination while remaining outside 50 metres.
  2. Move within 50 metres with reported horizontal accuracy of 50 metres or better.
  3. Observe the UI.
- **Expected result:** Arrival does not trigger early. One **You've Arrived** screen appears when both criteria pass.
- [ ] Pass  - [ ] Fail

### AR-02 — No safety work after arrival

- **Purpose:** Verify arrival is terminal for monitoring.
- **Preconditions/setup:** Arrived-but-unfinished session.
- **Exact steps:**
  1. Leave the completion screen open for more than 60 seconds.
  2. Simulate an off-route location.
  3. Background and foreground the app.
- **Expected result:** No periodic/off-route check-in, emergency escalation, reroute, or new location safety processing begins.
- [ ] Pass  - [ ] Fail

### AR-03 — Finish Journey

- **Purpose:** Verify explicit successful completion.
- **Preconditions/setup:** Arrived-but-unfinished session; note history count.
- **Exact steps:**
  1. Tap **Finish Journey** once.
  2. Return to home and open history.
  3. Relaunch SafeWalk.
- **Expected result:** Exactly one successful record appears with preserved metadata. The session and arrival state are cleared and no Resume card appears after relaunch.
- [ ] Pass  - [ ] Fail

### AR-04 — Arrived cold launch, then finish

- **Purpose:** Verify the critical arrival persistence requirement.
- **Preconditions/setup:** Reach **You've Arrived** and do not press Finish.
- **Exact steps:**
  1. Force-terminate SafeWalk from the app switcher.
  2. Relaunch it.
  3. Observe the home card and open it.
  4. Wait beyond a periodic interval and verify no safety event starts.
  5. Tap **Finish Journey**.
  6. Open history and relaunch once more.
- **Expected result:** Home identifies a completed SafeWalk, the completion screen restores without needing a location, no monitoring/check-in/emergency/reroute restarts, Finish remains available, exactly one successful record is saved, and the session stays cleared.
- [ ] Pass  - [ ] Fail

## Manual end

### ME-01 — End before destination

- **Purpose:** Verify unsuccessful completion and full cleanup.
- **Preconditions/setup:** Active journey before arrival; note history count.
- **Exact steps:**
  1. Tap **End Journey** and complete any confirmation UI.
  2. Return home and open history.
  3. Force-terminate and relaunch SafeWalk.
- **Expected result:** Exactly one record has `completedSuccessfully = false` in its displayed status, tracking and safety state are cleared, and no Resume card appears.
- [ ] Pass  - [ ] Fail

### ME-02 — End with unresolved safety state

- **Purpose:** Verify manual end clears pending resources.
- **Preconditions/setup:** Active check-in, emergency, or failed reroute state.
- **Exact steps:**
  1. End the journey.
  2. Wait beyond the prior check-in deadline.
  3. Relaunch the app.
- **Expected result:** No check-in, missed alert for active state, emergency view, retry, tracking, or resume state returns. One unsuccessful history record retains applicable safety summary flags.
- [ ] Pass  - [ ] Fail

## History

### HI-01 — Successful and manual records

- **Purpose:** Verify outcome classification and metadata.
- **Preconditions/setup:** Complete one journey through arrival and manually end another.
- **Exact steps:**
  1. Open Journey History.
  2. Compare both records' destination, dates, distance, outcome, and safety indicators.
- **Expected result:** Arrival is shown as successful, manual end as unsuccessful, and available off-route/check-in/expiry metadata matches each journey.
- [ ] Pass  - [ ] Fail

### HI-02 — History persistence

- **Purpose:** Verify normal launch never wipes valid history.
- **Preconditions/setup:** At least two records stored.
- **Exact steps:**
  1. Force-terminate and relaunch.
  2. Open Journey History.
- **Expected result:** Existing records remain, retain order and data, and no extra record was added by launch.
- [ ] Pass  - [ ] Fail

### HI-03 — Deletion

- **Purpose:** Verify supported record deletion.
- **Preconditions/setup:** At least one disposable history record.
- **Exact steps:**
  1. Use Edit/swipe deletion in Journey History.
  2. Leave and reopen history.
  3. Relaunch and check again.
- **Expected result:** The selected record is deleted, other records remain, and the deletion persists.
- [ ] Pass  - [ ] Fail

### HI-04 — Duplicate prevention

- **Purpose:** Verify one history write per journey.
- **Preconditions/setup:** Arrived session or manual-end flow; note history count.
- **Exact steps:**
  1. Rapidly activate the finish/end control if the system permits.
  2. Navigate back and reopen history.
  3. Relaunch and inspect history again.
- **Expected result:** Only one record exists for that journey UUID.
- [ ] Pass  - [ ] Fail

## Accessibility

### AX-01 — VoiceOver critical controls

- **Purpose:** Verify safety-critical actions are understandable without visual context.
- **Preconditions/setup:** Enable VoiceOver; prepare states containing destination search, active check-in, emergency, reroute error, arrival, and home resume.
- **Exact steps:**
  1. Navigate each state by swipe gestures.
  2. Focus **Start SafeWalk**, **Resume SafeWalk**, search/clear, **I'm Safe**, **Emergency Options**, **Call Emergency Contact**, **Share Location**, route/reroute retry, **End Journey**, and **Finish Journey**.
  3. Activate each control in a safe test state.
- **Expected result:** Each control has a meaningful nonduplicative name, useful hint where needed, correct enabled state, and predictable activation order.
- [ ] Pass  - [ ] Fail

### AX-02 — Dynamic Type

- **Purpose:** Verify content remains usable at large text sizes.
- **Preconditions/setup:** Set an Accessibility text size near the maximum.
- **Exact steps:**
  1. Inspect home, search results, route planning, active check-in, emergency, arrival, contact, and history screens.
  2. Scroll and activate primary actions.
- **Expected result:** Important text is readable, controls remain reachable, labels do not overlap critical values, and screens that need vertical space scroll.
- [ ] Pass  - [ ] Fail

## Physical device

### PD-01 — Real GPS and background journey

- **Purpose:** Validate behavior that Simulator cannot represent faithfully.
- **Preconditions/setup:** Signed build on a charged iPhone; safe outdoor walking route; Always location and notifications allowed.
- **Exact steps:**
  1. Start a short journey and walk along the route.
  2. Lock the phone or use another app for part of the walk.
  3. Reopen SafeWalk before arrival.
  4. Reach the destination and finish.
- **Expected result:** GPS and progress are plausible, the journey survives backgrounding, notifications arrive, arrival is detected without repeated events, and cleanup succeeds.
- [ ] Pass  - [ ] Fail

### PD-02 — Notification actions while locked

- **Purpose:** Verify system-level action delivery.
- **Preconditions/setup:** Physical iPhone, active journey, notifications shown on Lock Screen.
- **Exact steps:**
  1. Lock the device before a check-in notification.
  2. Use **I'm Safe** from the notification.
  3. Unlock and inspect SafeWalk.
- **Expected result:** The current event resolves once and follows its reason-specific behavior without creating a second event.
- [ ] Pass  - [ ] Fail

### PD-03 — Emergency SMS/share/call integration

- **Purpose:** Verify MessageUI and system URL/share integrations on hardware.
- **Preconditions/setup:** Physical iPhone with a controlled test contact; do not use a real emergency call for testing.
- **Exact steps:**
  1. Open each emergency communication action.
  2. Confirm recipient and content.
  3. Cancel before sending/calling unless a safe test recipient has agreed.
- **Expected result:** Each supported system interface opens correctly, missing capabilities are handled without a crash, and no action occurs automatically.
- [ ] Pass  - [ ] Fail

## Final regression

### FR-01 — Complete normal journey

- **Purpose:** Validate the primary experience end to end after all hardening changes.
- **Preconditions/setup:** Clean inactive state; location and notifications allowed; network available.
- **Exact steps:**
  1. Search for and select a destination.
  2. Load a walking route and start SafeWalk.
  3. Follow the route and resolve one periodic check-in with **I'm Safe**.
  4. Background and foreground the app once.
  5. Reach the destination.
  6. Confirm no further safety event starts.
  7. Tap **Finish Journey**.
  8. Verify history and relaunch.
- **Expected result:** Every transition occurs once, no inappropriate reroute occurs, arrival persists until explicit finish, one successful record is stored, all runtime/session state clears, and the app returns to the initial home state.
- [ ] Pass  - [ ] Fail

## Test completion

**Failed test IDs:** ________________________________________________  
**Release-blocking defects:** _______________________________________  
**Evidence/log location:** __________________________________________  
**Final manual QA decision:** [ ] Pass  [ ] Blocked

