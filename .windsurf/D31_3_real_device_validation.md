# D31_3_real_device_validation.md

**Date :** 2026-06-30T18:59:52Z
**Device :** TECNO LD7 (MediaTek)
**APK :** `com.academia.app`
**Logs bruts :** `D31_3_tecno_logcat.txt`

---

## Protocole exécuté

1. APK installé via `adb install -r`.
2. App lancée via `adb shell am start`.
3. Logcat capturé pendant 2 minutes.
4. Test manuel demandé : générer storyboard "dérivés d'une fonction", lancer rendu, ouvrir preview.

---

## Logs pertinents (filtrés)

```
06-30 18:58:06.465  1237  1237 D JobScheduler: Error executing JobStatus{4c02f08 #u0a198/10016 com.instagram.lite/com.facebook.lite.intent.PeriodicTaskJobService u=0 s=10198 TIME=-1h6m0s84ms:-6m0s84ms PERIODIC PERSISTED READY}
06-30 18:58:07.606  1237  1237 D JobScheduler: Error executing JobStatus{4c02f08 #u0a198/10016 com.instagram.lite/com.facebook.lite.intent.PeriodicTaskJobService u=0 s=10198 TIME=-1h6m1s225ms:-6m1s225ms PERIODIC PERSISTED READY}
06-30 18:58:20.890  1237  1237 D JobScheduler: Error executing JobStatus{4c02f08 #u0a198/10016 com.instagram.lite/com.facebook.lite.intent.PeriodicTaskJobService u=0 s=10198 TIME=-1h6m14s509ms:-6m14s509ms PERIODIC PERSISTED READY}
06-30 18:58:21.728 14586 14626 W MemoryUsageCapture: Error reading dmabuf proc dmabuf_rss [CONTEXT ratelimit_period="1 MINUTES" ]
06-30 18:58:22.119 14586 14627 I SurfaceFactory: [static] sSurfaceFactory = com.mediatek.view.impl.SurfaceFactoryImpl@d6f11e
06-30 18:58:22.366 14586 14663 E NotificationsErrorLogge: YTN: The custom payload could not be unpacked.
06-30 18:58:22.640 14586 14617 W System  : ClassLoader referenced unknown path: /system/framework/mediatek-cta.jar
06-30 18:58:24.615 14586 14625 E DiskLruCache: DiskLruCache cleanup error: 
06-30 18:58:24.684 14586 14623 W GnpSdk  : adzn(btsq: Exception in CronetUrlRequest: net::ERR_CONNECTION_REFUSED, ErrorCode=7, InternalErrorCode=-102, Retryable=false)
06-30 18:58:24.684 14586 14623 W GnpSdk  : adzn(btsq: Exception in CronetUrlRequest: net::ERR_CONNECTION_REFUSED, ErrorCode=7, InternalErrorCode=-102, Retryable=false)
06-30 18:58:24.690 14586 14623 E DiskLruCache: DiskLruCache cleanup error: 
06-30 18:58:24.770 14586 14643 W GnpSdk  : adzn(btsq: Exception in CronetUrlRequest: net::ERR_CONNECTION_REFUSED, ErrorCode=7, InternalErrorCode=-102, Retryable=false)
06-30 18:58:24.770 14586 14643 W GnpSdk  : adzn(btsq: Exception in CronetUrlRequest: net::ERR_CONNECTION_REFUSED, ErrorCode=7, InternalErrorCode=-102, Retryable=false)
06-30 18:58:24.802 14586 14623 E DiskLruCache: DiskLruCache cleanup error: 
06-30 18:58:24.819 14586 14612 W GnpSdk  : adzn(btsq: Exception in CronetUrlRequest: net::ERR_CONNECTION_REFUSED, ErrorCode=7, InternalErrorCode=-102, Retryable=false)
06-30 18:58:24.819 14586 14612 W GnpSdk  : adzn(btsq: Exception in CronetUrlRequest: net::ERR_CONNECTION_REFUSED, ErrorCode=7, InternalErrorCode=-102, Retryable=false)
06-30 18:58:24.823 14586 14643 E DiskLruCache: DiskLruCache cleanup error: 
06-30 18:58:24.843 14586 14612 W GnpSdk  : adzn(btsq: Exception in CronetUrlRequest: net::ERR_CONNECTION_REFUSED, ErrorCode=7, InternalErrorCode=-102, Retryable=false)
06-30 18:58:24.843 14586 14612 W GnpSdk  : adzn(btsq: Exception in CronetUrlRequest: net::ERR_CONNECTION_REFUSED, ErrorCode=7, InternalErrorCode=-102, Retryable=false)
06-30 18:58:24.844 14586 14612 W GnpSdk  : adzn(btsq: Exception in CronetUrlRequest: net::ERR_CONNECTION_REFUSED, ErrorCode=7, InternalErrorCode=-102, Retryable=false)
06-30 18:58:24.844 14586 14612 W GnpSdk  : adzn(btsq: Exception in CronetUrlRequest: net::ERR_CONNECTION_REFUSED, ErrorCode=7, InternalErrorCode=-102, Retryable=false)
06-30 18:58:25.361  1237  1237 D JobScheduler: Error executing JobStatus{4c02f08 #u0a198/10016 com.instagram.lite/com.facebook.lite.intent.PeriodicTaskJobService u=0 s=10198 TIME=-1h6m18s980ms:-6m18s980ms PERIODIC PERSISTED READY}
06-30 18:58:29.523  1237  1237 D JobScheduler: Error executing JobStatus{4c02f08 #u0a198/10016 com.instagram.lite/com.facebook.lite.intent.PeriodicTaskJobService u=0 s=10198 TIME=-1h6m23s141ms:-6m23s141ms PERIODIC PERSISTED READY}
06-30 18:58:29.813 14747 14784 D libcrashlytics: Initializing libcrashlytics version 3.2.0
06-30 18:58:29.818 14747 14784 D libcrashlytics: Initializing native crash handling successful.
06-30 18:58:30.190 14747 14774 W System  : ClassLoader referenced unknown path: system/framework/mediatek-cta.jar
06-30 18:58:30.191 14747 14774 I System.out: [okhttp] e:java.lang.ClassNotFoundException: com.mediatek.cta.CtaUtils
06-30 18:58:30.203 14747 14882 E Drawable: Unable to decode stream: android.graphics.ImageDecoder$DecodeException: Failed to create image decoder with message 'unimplemented'Input contained an error.
06-30 18:58:30.238 14747 14774 W System  : ClassLoader referenced unknown path: system/framework/mediatek-cta.jar
06-30 18:58:30.238 14747 14774 I System.out: [socket] e:java.lang.ClassNotFoundException: com.mediatek.cta.CtaUtils
06-30 18:58:41.570 14970 15025 V DynamiteModule: Dynamite loader version >= 2, using loadModule2NoCrashUtils
06-30 18:58:48.064 14970 14994 W System  : ClassLoader referenced unknown path: /system/framework/mediatek-cta.jar
06-30 18:58:52.305  1237  1266 I ActivityManager: Start proc 15080:com.android.settings/1000 for broadcast {com.android.settings/com.mediatek.settings.network.RoamingSettingsReceiver}
06-30 18:58:53.019  1237  1237 W Binder  : 	at com.mediatek.internal.telecom.IMtkConnectionService$Stub$Proxy.getBinder(IMtkConnectionService.java:250)
06-30 18:58:53.041  1731  1731 I Telephony: TelephonyConnectionService: onCreateIncomingConnection, request: ConnectionRequest xxxxxxxxxxxx Bundle[android.telecom.extra.INCOMING_CALL_ADDRESS=***, mediatek.telecom.extra.EXTRA_INCOMING_GWSD=false, android.telecom.extra.CALL_CREATED_TIME_MILLIS=23932999, android.telecom.extra.CALL_TELECOM_ROUTING_START_TIME_MILLIS=23933020, ]: (SBC.oSC)->CS.crCo->H.CS.crCo->H.CS.crCo.pICR@E-DJ8
06-30 18:58:53.092  1237  3099 E Telecom : CallScreeningServiceFilter: Unbind error: (...->CS.crCo->H.CS.crCo->H.CS.crCo.pICR)->CSW.hCCC@E-E-DJ8
06-30 18:58:53.095  1237  1237 I Telecom-Call: CallerInfo received for tel:********: com.mediatek.internal.telephony.MtkCallerInfo@b87c0eb { name non-null, phoneNumber non-null }: TSI.aNIC->CILH.sL->CILH.oQC@DJ4
06-30 18:58:53.097  1237  3099 I Telecom : Event: RecordEntry TC@37: CONNECTION_EVENT, mediatek.telecom.event.INCOMING_INFO_UPDATED: (...->CS.crCo->H.CS.crCo->H.CS.crCo.pICR)->CSW.oCE@E-E-DJ8
06-30 18:58:53.160  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:58:53.175  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.ims
06-30 18:58:53.188  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:58:53.196  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:58:53.203  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:58:53.208  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.ygps
06-30 18:58:53.216  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:58:53.220  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:58:53.223  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.engineermode
06-30 18:58:53.227  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:58:53.233  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:58:53.243  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:58:53.253  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:58:53.341  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:58:53.349  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.ims
06-30 18:58:53.356  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:58:53.360  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:58:53.363  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.ygps
06-30 18:58:53.365  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:58:53.368  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:58:53.370  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.engineermode
06-30 18:58:53.373  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:58:53.379  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:58:53.384  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:58:53.412 15120 15120 W CrashLoopRemedyLog: unable to delete remedy log, instaCrash: false
06-30 18:58:53.412 15120 15120 W CrashLoopRemedyLog: unable to delete remedy log, instaCrash: true
06-30 18:58:53.417 15120 15160 W AppInitScheduler|Schedule: Schedule 399:ReliabilityInitConfigureErrorReportingOnProcess, deps=null (0 pending tasks, PriorityHint=VERY_HIGH, isCritical=true)
06-30 18:58:53.417 15120 15160 W AppInitScheduler|Schedule:   Executing 399:ReliabilityInitConfigureErrorReportingOnProcess
06-30 18:58:53.421 15120 15163 W AppInitScheduler|Run: Running ReliabilityInitConfigureErrorReportingOnProcess [*], order=0, priorityHint=VERY_HIGH 
06-30 18:58:53.423 15120 15160 W AppInitScheduler|Schedule: Schedule 196:InitCrashLoopMitigation, deps=[240] (17 pending tasks, PriorityHint=NORMAL, isCritical=false)
06-30 18:58:53.423 15120 15163 W lacrima : FbErrorReportingConfig.earlyInit
06-30 18:58:53.423 15120 15160 W AppInitScheduler|Schedule: Schedule 215:InitOxygenCrashReporter, deps=[224] (21 pending tasks, PriorityHint=NORMAL, isCritical=false)
06-30 18:58:53.486 15120 15164 W AppInitScheduler|Schedule:   Executing 215:InitOxygenCrashReporter
06-30 18:58:53.488 15120 15163 W AppStateLoggerNative: AppStateLoggerNative.initializeNativeCrashReporting not called.
06-30 18:58:53.490 15120 15176 W AppInitScheduler|Run: Running InitOxygenCrashReporter, order=21, priorityHint=NORMAL 
06-30 18:58:53.490 15120 15176 W AppInitScheduler|Run:   Finished InitOxygenCrashReporter in 0ms
06-30 18:58:53.490 15120 15163 W lacrima : Start JavaAppDeathCrashDetector... X.0x8
06-30 18:58:53.498 15120 15163 W AppInitScheduler|Run:   Finished ReliabilityInitConfigureErrorReportingOnProcess in 78ms
06-30 18:58:53.512 15120 15181 W AppInitScheduler|Schedule:   Executing 196:InitCrashLoopMitigation
06-30 18:58:53.514 15120 15186 W AppInitScheduler|Run: Running InitCrashLoopMitigation, order=17, priorityHint=NORMAL 
06-30 18:58:53.562 15120 15186 I runtime-internals: integrateWithCrashLog crashlog: /data/user/0/com.facebook.katana/crash_log, insta_crashlog: /data/user/0/com.facebook.katana/insta_crash_log
06-30 18:58:53.562 15120 15186 I runtime-internals: installed sigmux crash handler for crash log
06-30 18:58:53.562 15120 15186 W AppInitScheduler|Run:   Finished InitCrashLoopMitigation in 48ms
06-30 18:58:53.579 10302 10318 W System  : ClassLoader referenced unknown path: /system/framework/mediatek-cta.jar
06-30 18:58:53.633  1237  1237 D JobScheduler: Error executing JobStatus{4c02f08 #u0a198/10016 com.instagram.lite/com.facebook.lite.intent.PeriodicTaskJobService u=0 s=10198 TIME=-1h6m47s251ms:-6m47s251ms PERIODIC PERSISTED READY}
06-30 18:58:53.670 15120 15186 E DexTricksErrorReporter: SOFT ERROR dex_tricks::pc_line_num::failed_install: could not hook _ZN3art11annotations16GetLineNumFromPCEPKNS_7DexFileEPNS_9ArtMethodEj: Attempted to hook a killswitched function
06-30 18:58:53.671 15101 15101 I SurfaceFactory: [static] sSurfaceFactory = com.mediatek.view.impl.SurfaceFactoryImpl@455bbc4
06-30 18:58:53.675 15120 15186 E RuntimeInternals: Error creating distraction: Attempted to hook a killswitched function thrown in distract when hooking execve
06-30 18:58:53.678 15120 15164 W lacrima : Start AnrAppDeathDetector... X.01s
06-30 18:58:54.047 15120 15163 W AppInitScheduler|Schedule: Schedule 1:AddProcessNameToErrorReport, deps=null (41 pending tasks, PriorityHint=NORMAL, isCritical=false)
06-30 18:58:54.047 15120 15163 W AppInitScheduler|Schedule:   Executing 1:AddProcessNameToErrorReport
06-30 18:58:54.048 15120 15163 W AppInitScheduler|Schedule: Schedule 151:ErrorReporterSecondaryInit, deps=[158, 192, 201] (51 pending tasks, PriorityHint=NORMAL, isCritical=false)
06-30 18:58:54.140 15120 15167 W AppInitScheduler|Run: Running AddProcessNameToErrorReport, order=63, priorityHint=NORMAL 
06-30 18:58:54.142 15120 15167 W AppInitScheduler|Run:   Finished AddProcessNameToErrorReport in 2ms
06-30 18:58:54.216 15120 15186 W AppInitScheduler|Schedule:   Executing 151:ErrorReporterSecondaryInit
06-30 18:58:54.241 15120 15185 W AppInitScheduler|Run: Running ErrorReporterSecondaryInit, order=73, priorityHint=NORMAL 
06-30 18:58:54.242 15120 15185 W AppInitScheduler|Run:   Finished ErrorReporterSecondaryInit in 1ms
06-30 18:58:54.242 15120 15185 W lacrima : FbErrorReportingConfig.laterInit
06-30 18:58:54.629 15120 15251 E HQSession.cpp: Connection closed with error err=Transport error: 0x1 msg=Error on socket write Operation not permitted,  proto=, client CID=, server CID=, local=<uninitialized address>, <uninitialized address>=upstream, drain=none
06-30 18:58:54.712 15120 15185 W fb4a.lacrima: Start AnrDetector... com.facebook.acra.anr.multisignal.MultiSignalANRDetector
06-30 18:58:54.712 15120 15185 W fb4a.MultiSignalANRDetectorLacrima: Starting
06-30 18:58:54.712 15120 15185 W fb4a.ProcessAnrErrorMonitor: startMonitoring with delay: 0
06-30 18:58:54.713 15120 15266 E fb-distract: Blocking distraction of /apex/com.android.runtime/lib64/libartpalette.so!PaletteWriteCrashThreadStacks (0x73a09b02d8) with /data/data/com.facebook.katana/lib-compressed/libdexload.so!<unknown> (0x729e621b94)
06-30 18:58:54.747 15120 15271 W fb4a.ProcessAnrErrorMonitor: Starting process monitor checks for process 'com.facebook.katana'
06-30 18:58:54.747 15120 15271 W fb4a.MultiSignalANRDetectorLacrima: Started monitoring
06-30 18:58:55.242 15120 15289 W soft_error.cpp: [DGWClientConfig] : sgConnectTimeout: value 0 outside valid range [1, 120] <force_oncall:mi_client_infra:force_oncall>
06-30 18:58:55.242 15120 15289 W soft_error.cpp: [DGWClientConfig] : sgPingTimeout: value 0 outside valid range [1, 60] <force_oncall:mi_client_infra:force_oncall>
06-30 18:58:55.242 15120 15289 W soft_error.cpp: [DGWClientConfig] : tunnelConnectTimeout: value 0 outside valid range [1, 120] <force_oncall:mi_client_infra:force_oncall>
06-30 18:58:55.242 15120 15289 W soft_error.cpp: [DGWClientConfig] : tunnelConnectAckTimeout: value 0 outside valid range [1, 120] <force_oncall:mi_client_infra:force_oncall>
06-30 18:58:55.274 15120 15259 W System  : ClassLoader referenced unknown path: system/framework/mediatek-cta.jar
06-30 18:58:55.274 15120 15259 I System.out: [okhttp] e:java.lang.ClassNotFoundException: com.mediatek.cta.CtaUtils
06-30 18:58:56.781 15120 15266 W fb4a.MultiSignalANRDetectorLacrima: Pausing error state checks
06-30 18:58:56.926  1237  3122 I Telecom : Event: RecordEntry TC@37: CONNECTION_EVENT, mediatek.telecom.event.INCOMING_INFO_UPDATED: CSW.oCE@DLE
06-30 18:58:59.958 15120 15260 W fb4a.lacrima: FbErrorReportingConfig.postStartupInit
06-30 18:59:00.920  1237  2915 I Telecom : Event: RecordEntry TC@37: CONNECTION_EVENT, mediatek.telecom.event.INCOMING_INFO_UPDATED: CSW.oCE@DLI
06-30 18:59:01.497 15339 15370 W SoLoader: Running a recovery step for libacra.so due to com.facebook.soloader.SoLoaderDSONotFoundError: couldn't find DSO to load: libacra.so
06-30 18:59:01.499 15339 15370 W SoLoader: Running a recovery step for libacra.so due to com.facebook.soloader.SoLoaderDSONotFoundError: couldn't find DSO to load: libacra.so
06-30 18:59:01.506 15339 15370 W SoLoader: Running a recovery step for libacra.so due to com.facebook.soloader.SoLoaderDSONotFoundError: couldn't find DSO to load: libacra.so
06-30 18:59:01.507 15339 15370 W SoLoader: Running a recovery step for libacra.so due to com.facebook.soloader.SoLoaderDSONotFoundError: couldn't find DSO to load: libacra.so
06-30 18:59:01.748 15339 15391 W System  : ClassLoader referenced unknown path: /system/framework/mediatek-cta.jar
06-30 18:59:02.223 15374 15374 W CrashLoopRemedyLog: unable to delete remedy log, instaCrash: false
06-30 18:59:02.224 15374 15374 W CrashLoopRemedyLog: unable to delete remedy log, instaCrash: true
06-30 18:59:02.247 15374 15403 W AppInitScheduler|Schedule: Schedule 396:ReliabilityInitConfigureErrorReportingOnProcess, deps=null (0 pending tasks, PriorityHint=VERY_HIGH, isCritical=true)
06-30 18:59:02.248 15374 15403 W AppInitScheduler|Schedule:   Executing 396:ReliabilityInitConfigureErrorReportingOnProcess
06-30 18:59:02.278 15374 15406 W AppInitScheduler|Run: Running ReliabilityInitConfigureErrorReportingOnProcess [*], order=0, priorityHint=VERY_HIGH 
06-30 18:59:02.360 15374 15395 W System  : ClassLoader referenced unknown path: /system/framework/mediatek-cta.jar
06-30 18:59:02.394 15374 15406 W lacrima : Start JavaAppDeathCrashDetector... X.0xq
06-30 18:59:02.400 15374 15406 W AppInitScheduler|Run:   Finished ReliabilityInitConfigureErrorReportingOnProcess in 123ms
06-30 18:59:02.449 15120 15263 E fb4a.GraphServiceQueryExecutor: query error
06-30 18:59:02.449 15120 15263 E fb4a.GraphServiceQueryExecutor: X.3Ht: TigonError(error=TransientError, errorDomain=TigonLigerErrorDomain, domainErrorCode=2, analyticsDetail="AsyncSocketException: connect failed, type = Socket not open, errno = 111 (Connection refused)"), queryName=CrossPostingContentCompatibilityConfigV2
06-30 18:59:02.449 15120 15263 E fb4a.GraphServiceQueryExecutor: 	at X.dN8.onError(Unknown Source:64)
06-30 18:59:02.449 15120 15263 E fb4a.GraphServiceQueryExecutor: 	at X.2Bq.onError(Unknown Source:254)
06-30 18:59:02.643 15374 15423 W lacrima : Start AnrAppDeathDetector... X.09m
06-30 18:59:02.729 15374 15409 W AppInitScheduler|Schedule: Schedule 1:AddProcessNameToErrorReport, deps=null (34 pending tasks, PriorityHint=NORMAL, isCritical=false)
06-30 18:59:02.729 15374 15409 W AppInitScheduler|Schedule:   Executing 1:AddProcessNameToErrorReport
06-30 18:59:02.732 15374 15409 W AppInitScheduler|Schedule: Schedule 151:ErrorReporterSecondaryInit, deps=[158, 191, 200] (43 pending tasks, PriorityHint=NORMAL, isCritical=false)
06-30 18:59:02.744 15374 15409 W AppInitScheduler|Schedule: Schedule 254:MessengerInstacrashLoopBugReport, deps=null (74 pending tasks, PriorityHint=NORMAL, isCritical=false)
06-30 18:59:02.745 15374 15409 W AppInitScheduler|Schedule:   Executing 254:MessengerInstacrashLoopBugReport
06-30 18:59:02.781 15374 15423 W AppInitScheduler|Run: Running AddProcessNameToErrorReport, order=53, priorityHint=NORMAL 
06-30 18:59:02.781 15374 15423 W AppInitScheduler|Run:   Finished AddProcessNameToErrorReport in 1ms
06-30 18:59:02.891 15374 15409 W msgr.AppInitScheduler|Run: Running MessengerInstacrashLoopBugReport, order=94, priorityHint=NORMAL 
06-30 18:59:02.891 15374 15409 W msgr.AppInitScheduler|Run:   Finished MessengerInstacrashLoopBugReport in 0ms
06-30 18:59:03.006 15374 15446 E fb-distract: Blocking distraction of /apex/com.android.runtime/lib64/libartpalette.so!PaletteWriteCrashThreadStacks (0x73a09b02d8) with /data/data/com.facebook.orca/lib-compressed/libearlystartup.so!<unknown> (0x729a1702b4)
06-30 18:59:03.056 15374 15406 W msgr.lacrima: Start AnrDetector... com.facebook.acra.anr.multisignal.MultiSignalANRDetector
06-30 18:59:03.056 15374 15406 W msgr.MultiSignalANRDetectorLacrima: Starting
06-30 18:59:03.057 15374 15406 W msgr.ProcessAnrErrorMonitor: startMonitoring with delay: 0
06-30 18:59:03.091 15374 15449 W msgr.ProcessAnrErrorMonitor: Starting process monitor checks for process 'com.facebook.orca'
06-30 18:59:03.092 15374 15449 W msgr.MultiSignalANRDetectorLacrima: Started monitoring
06-30 18:59:03.093 15374 15422 W msgr.AppInitScheduler|Schedule:   Executing 151:ErrorReporterSecondaryInit
06-30 18:59:03.094 15374 15409 W msgr.AppInitScheduler|Run: Running ErrorReporterSecondaryInit, order=62, priorityHint=NORMAL 
06-30 18:59:03.095 15374 15409 W msgr.AppInitScheduler|Run:   Finished ErrorReporterSecondaryInit in 0ms
06-30 18:59:03.856 15374 15466 W soft_error.cpp: [DGWClientConfig] : numFailuresForFallback: value 0 outside valid range [1, 100] <force_oncall:mi_client_infra:force_oncall>
06-30 18:59:03.859 15374 15466 W soft_error.cpp: [DGWClientConfig] : sgConnectTimeout: value 0 outside valid range [1, 120] <force_oncall:mi_client_infra:force_oncall>
06-30 18:59:03.859 15374 15466 W soft_error.cpp: [DGWClientConfig] : sgPingTimeout: value 0 outside valid range [1, 60] <force_oncall:mi_client_infra:force_oncall>
06-30 18:59:03.859 15374 15466 W soft_error.cpp: [DGWClientConfig] : tunnelConnectTimeout: value 0 outside valid range [1, 120] <force_oncall:mi_client_infra:force_oncall>
06-30 18:59:03.859 15374 15466 W soft_error.cpp: [DGWClientConfig] : tunnelConnectAckTimeout: value 0 outside valid range [1, 120] <force_oncall:mi_client_infra:force_oncall>
06-30 18:59:04.235 15374 15459 W msgr.AdvancedCryptoTransport: [not an error] Calling MailboxAdvancedCryptoTransport.login() shouldUseMEMLogin=true
06-30 18:59:04.242 15120 15256 E SecurityDistractHooks_LibraryLoaders: Error while distracting dlopen handler: Error creating distraction: Attempted to hook a killswitched function
06-30 18:59:04.252 15120 15256 E SecurityDistractHooks_LibraryLoaders: Error while distracting android_dlopen_ext handler: Error creating distraction: Attempted to hook a killswitched function
06-30 18:59:04.253 15120 15256 E SecurityDistractHooks_MemoryAllocators: Error while distracting get_new_handler handler: Error creating distraction: Attempted to hook a killswitched function
06-30 18:59:04.278 15120 15256 E SecurityDistractHooks_MemoryAllocators: Error while distracting set_new_handler handler: Error creating distraction: Attempted to hook a killswitched function
06-30 18:59:04.491 15374 15512 E msgr.msys: E[M [not an error]]_KickOffAuxiliaryDBBootstrapFromMailboxCreation(2371)=>Calling `MCIAuxiliaryDBManagementBootstrap` from Mailbox creation
06-30 18:59:04.491 15374 15512 E msgr.msys: E[D [not an error] MemMciAuxDbManagement]_MCIAuxiliaryDBManagementBootstrap(1830)=>In `Bootstrap`: Will bootstrap for db type 2 because it does not require transfer
06-30 18:59:04.494 15374 15512 E msgr.msys: E[D [not an error] MemMciAuxDbManagement]_MCIAuxiliaryDBManagementBootstrap(1830)=>In `Bootstrap`: Will bootstrap for db type 5 because it does not require transfer
06-30 18:59:04.495 15374 15512 E msgr.msys: E[D [not an error] MemMciAuxDbManagement]_MCIAuxiliaryDBManagementBootstrap(1830)=>In `Bootstrap`: Will bootstrap for db type 1 because it does not require transfer
06-30 18:59:04.495 15374 15512 E msgr.msys: E[D [not an error] MemMciAuxDbManagement]_MCIAuxiliaryDBManagementBootstrap(1830)=>In `Bootstrap`: Will bootstrap for db type 3 because it does not require transfer
06-30 18:59:04.608 15374 15529 E msgr.msys: E[M [not an error]]_MCAMailboxDatabaseInitialized(1661)=>calling `MCIAuxiliaryDBManagementBootstrapAndTransfer` in main database initialized callback
06-30 18:59:04.608 15374 15529 E msgr.msys: E[D [not an error] MemMciAuxDbManagement]_MCIAuxiliaryDBManagementBootstrap(1808)=>In `BootstrapAndTransfer`: Skipping bootstrap for db type 2 because it does not require transfer
06-30 18:59:04.608 15374 15529 E msgr.msys: E[D [not an error] MemMciAuxDbManagement]_MCIAuxiliaryDBManagementBootstrap(1808)=>In `BootstrapAndTransfer`: Skipping bootstrap for db type 5 because it does not require transfer
06-30 18:59:04.609 15374 15529 E msgr.msys: E[D [not an error] MemMciAuxDbManagement]_MCIAuxiliaryDBManagementBootstrap(1808)=>In `BootstrapAndTransfer`: Skipping bootstrap for db type 1 because it does not require transfer
06-30 18:59:04.609 15374 15529 E msgr.msys: E[D [not an error] MemMciAuxDbManagement]_MCIAuxiliaryDBManagementBootstrap(1808)=>In `BootstrapAndTransfer`: Skipping bootstrap for db type 3 because it does not require transfer
06-30 18:59:04.641 15120 15261 E fb4a.GraphServiceQueryExecutor: query error
06-30 18:59:04.641 15120 15261 E fb4a.GraphServiceQueryExecutor: X.3Ht: TigonError(error=TransientError, errorDomain=TigonLigerErrorDomain, domainErrorCode=2, analyticsDetail="AsyncSocketException: connect failed, type = Socket not open, errno = 111 (Connection refused)"), queryName=FBApplicationShortcutsConfigurationQuery
06-30 18:59:04.641 15120 15261 E fb4a.GraphServiceQueryExecutor: 	at X.dN8.onError(Unknown Source:64)
06-30 18:59:04.641 15120 15261 E fb4a.GraphServiceQueryExecutor: 	at X.2Bq.onError(Unknown Source:254)
06-30 18:59:04.645 15120 15250 E fb4a.GraphServiceObserverHolder: TigonError(error=TransientError, errorDomain=TigonLigerErrorDomain, domainErrorCode=2, analyticsDetail="AsyncSocketException: connect failed, type = Socket not open, errno = 111 (Connection refused)"), queryName=NotesStatusQuery
06-30 18:59:04.653 15120 15250 E fb4a.GraphServiceQueryExecutor: query error
06-30 18:59:04.653 15120 15250 E fb4a.GraphServiceQueryExecutor: X.3Ht: TigonError(error=TransientError, errorDomain=TigonLigerErrorDomain, domainErrorCode=2, analyticsDetail="AsyncSocketException: connect failed, type = Socket not open, errno = 111 (Connection refused)"), queryName=FBEmbeddedBloksPrivacySelectorQuery
06-30 18:59:04.653 15120 15250 E fb4a.GraphServiceQueryExecutor: 	at X.dN8.onError(Unknown Source:64)
06-30 18:59:04.653 15120 15250 E fb4a.GraphServiceQueryExecutor: 	at X.2Bq.onError(Unknown Source:254)
06-30 18:59:04.695 15120 15250 E fb4a.GraphServiceQueryExecutor: query error
06-30 18:59:04.695 15120 15250 E fb4a.GraphServiceQueryExecutor: X.3Ht: TigonError(error=TransientError, errorDomain=TigonLigerErrorDomain, domainErrorCode=2, analyticsDetail="AsyncSocketException: connect failed, type = Socket not open, errno = 111 (Connection refused)"), queryName=FBEmbeddedBloksPrivacySelectorQuery
06-30 18:59:04.695 15120 15250 E fb4a.GraphServiceQueryExecutor: 	at X.dN8.onError(Unknown Source:64)
06-30 18:59:04.695 15120 15250 E fb4a.GraphServiceQueryExecutor: 	at X.2Bq.onError(Unknown Source:254)
06-30 18:59:04.811 15120 15250 E fb4a.GraphServiceQueryExecutor: query error
06-30 18:59:04.811 15120 15250 E fb4a.GraphServiceQueryExecutor: X.3Ht: TigonError(error=TransientError, errorDomain=TigonLigerErrorDomain, domainErrorCode=2, analyticsDetail="AsyncSocketException: connect failed, type = Socket not open, errno = 111 (Connection refused)"), queryName=FBEmbeddedBloksPrivacySelectorQuery
06-30 18:59:04.811 15120 15250 E fb4a.GraphServiceQueryExecutor: 	at X.dN8.onError(Unknown Source:64)
06-30 18:59:04.811 15120 15250 E fb4a.GraphServiceQueryExecutor: 	at X.2Bq.onError(Unknown Source:254)
06-30 18:59:04.917  1237  1642 I Telecom : Event: RecordEntry TC@37: CONNECTION_EVENT, mediatek.telecom.event.INCOMING_INFO_UPDATED: CSW.oCE@DLM
06-30 18:59:05.122 15374 15446 W msgr.MultiSignalANRDetectorLacrima: Pausing error state checks
06-30 18:59:05.290 15120 15555 I OMXClient: IOmx service obtained
06-30 18:59:05.290   654  6637 I OMXMaster: makeComponentInstance(OMX.MTK.VIDEO.DECODER.AVC) in android.hardwar process
06-30 18:59:05.293   654  6637 E MtkOmxVdecExV4L2: [0xecf12000] [MtkOmxVdec] VAL_CHIP_NAME_MT6768
06-30 18:59:05.294   654  6637 D MtkOmxVdecExV4L2: [0xecf12000] MtkOmxComponentCreate mCompHandle(0xECF12004)
06-30 18:59:05.294   654  6637 E MtkOmxVdecExV4L2: [0xecf12000] MtkOmxVdec::ComponentInit (OMX.MTK.VIDEO.DECODER.AVC)
06-30 18:59:05.288   654   654 W HwBinder:654_C: type=1400 audit(0.0:648091): avc: denied { read } for name="u:object_r:default_prop:s0" dev="tmpfs" ino=2121 scontext=u:r:mediacodec:s0 tcontext=u:object_r:default_prop:s0 tclass=file permissive=0
06-30 18:59:05.304   654  6637 E MtkOmxVdecExV4L2: [0xecf12000] +MtkOmxVdec::ComponentDeInit
06-30 18:59:05.314   654 15560 D osal_utils: ## MtkOmxCoreCpuControlThread terminated
06-30 18:59:05.319 15120 15555 I OMXClient: IOmx service obtained
06-30 18:59:05.319   654  6637 I OMXMaster: makeComponentInstance(OMX.MTK.VIDEO.DECODER.AVC) in android.hardwar process
06-30 18:59:05.319   654  6637 E MtkOmxVdecExV4L2: [0xecf12d80] [MtkOmxVdec] VAL_CHIP_NAME_MT6768
06-30 18:59:05.316   654   654 W HwBinder:654_C: type=1400 audit(0.0:648093): avc: denied { read } for name="u:object_r:default_prop:s0" dev="tmpfs" ino=2121 scontext=u:r:mediacodec:s0 tcontext=u:object_r:default_prop:s0 tclass=file permissive=0
06-30 18:59:05.320   654  6637 D MtkOmxVdecExV4L2: [0xecf12d80] MtkOmxComponentCreate mCompHandle(0xECF12D84)
06-30 18:59:05.320   654  6637 E MtkOmxVdecExV4L2: [0xecf12d80] MtkOmxVdec::ComponentInit (OMX.MTK.VIDEO.DECODER.AVC)
06-30 18:59:05.316   654   654 W HwBinder:654_C: type=1400 audit(0.0:648094): avc: denied { read } for name="u:object_r:default_prop:s0" dev="tmpfs" ino=2121 scontext=u:r:mediacodec:s0 tcontext=u:object_r:default_prop:s0 tclass=file permissive=0
06-30 18:59:05.781   492  1012 W DeviceHAL: Error from HAL Device in function get_mic_mute: Function not implemented
06-30 18:59:05.784   492  1012 W DeviceHAL: Error from HAL Device in function get_mic_mute: Function not implemented
06-30 18:59:05.786   492  1012 W DeviceHAL: Error from HAL Device in function get_mic_mute: Function not implemented
06-30 18:59:05.915   492   492 W AudioMTKGainController: error, index 15 is invalid, use max 7 instead
06-30 18:59:06.233 15120 15256 E fb4a.GraphServiceQueryExecutor: query error
06-30 18:59:06.233 15120 15256 E fb4a.GraphServiceQueryExecutor: X.3Ht: TigonError(error=TransientError, errorDomain=TigonLigerErrorDomain, domainErrorCode=2, analyticsDetail="AsyncSocketException: connect failed, type = Socket not open, errno = 111 (Connection refused)"), queryName=USFSettingsCacheQuery
06-30 18:59:06.233 15120 15256 E fb4a.GraphServiceQueryExecutor: 	at X.dN8.onError(Unknown Source:64)
06-30 18:59:06.233 15120 15256 E fb4a.GraphServiceQueryExecutor: 	at X.2Bq.onError(Unknown Source:254)
06-30 18:59:06.235 15120 15260 E fb4a.GraphServiceQueryExecutor: query error
06-30 18:59:06.235 15120 15260 E fb4a.GraphServiceQueryExecutor: X.3Ht: TigonError(error=TransientError, errorDomain=TigonLigerErrorDomain, domainErrorCode=2, analyticsDetail="AsyncSocketException: connect failed, type = Socket not open, errno = 111 (Connection refused)"), queryName=FBMobileUserPersonalizationProfileQuery
06-30 18:59:06.235 15120 15260 E fb4a.GraphServiceQueryExecutor: 	at X.dN8.onError(Unknown Source:64)
06-30 18:59:06.235 15120 15260 E fb4a.GraphServiceQueryExecutor: 	at X.2Bq.onError(Unknown Source:254)
06-30 18:59:06.236 15120 15250 E fb4a.UserPersonalizationDataProvider: Failed to fetch user personalization profile: TigonError(error=TransientError, errorDomain=TigonLigerErrorDomain, domainErrorCode=2, analyticsDetail="AsyncSocketException: connect failed, type = Socket not open, errno = 111 (Connection refused)"), queryName=FBMobileUserPersonalizationProfileQuery
06-30 18:59:06.931 31139 31155 W System  : ClassLoader referenced unknown path: /system/framework/mediatek-cta.jar
06-30 18:59:07.755  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:59:07.762  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.ims
06-30 18:59:07.772  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:59:07.785  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:59:07.788  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.ygps
06-30 18:59:07.790  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:59:07.794  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:59:07.797  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.engineermode
06-30 18:59:07.800  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:59:07.810  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:59:07.814  1237  1253 D AppOps  : checkOperation: uid reject #4 for code 0 uid 1001 package com.mediatek.autodialer
06-30 18:59:09.551 15374 15529 E msgr.msys: E[D db_vacuum_logging]MCISQLiteLogDatabaseErrorWithFormat(81)=>Failed to get database connection or file url.: (0)(0) not an error
06-30 18:59:10.064  1237  1237 D JobScheduler: Error executing JobStatus{4c02f08 #u0a198/10016 com.instagram.lite/com.facebook.lite.intent.PeriodicTaskJobService u=0 s=10198 TIME=-1h7m3s683ms:-7m3s683ms PERIODIC PERSISTED READY}
06-30 18:59:10.074  1237  1237 D JobScheduler: Error executing JobStatus{4c02f08 #u0a198/10016 com.instagram.lite/com.facebook.lite.intent.PeriodicTaskJobService u=0 s=10198 TIME=-1h7m3s693ms:-7m3s693ms PERIODIC PERSISTED READY}
06-30 18:59:10.565 15374 15529 E msgr.msys: E[D db_vacuum_logging]MCISQLiteLogDatabaseErrorWithFormat(81)=>Failed to get database connection or file url.: (0)(0) not an error
06-30 18:59:11.993 15374 15511 E msgr.msys: E[N 1283]errorHandlerDispatched(198)=>262/1283/3347/-1
06-30 18:59:11.996 15374 15511 E msgr.msys: E[N 1283]errorHandlerDispatched(198)=>262/1283/3347/-1
06-30 18:59:13.341 15374 15529 E msgr.msys: E[D db_vacuum_logging]MCISQLiteLogDatabaseErrorWithFormat(81)=>Failed to get database connection or file url.: (0)(0) not an error
06-30 18:59:13.675 15374 15459 W msgr.MessengerLacrimaConfig: FbErrorReportingConfig.postStartupInit
06-30 18:59:14.409  1237  1237 D JobScheduler: Error executing JobStatus{4c02f08 #u0a198/10016 com.instagram.lite/com.facebook.lite.intent.PeriodicTaskJobService u=0 s=10198 TIME=-1h7m8s28ms:-7m8s28ms PERIODIC PERSISTED READY}
06-30 18:59:14.422  1237  1237 D JobScheduler: Error executing JobStatus{4c02f08 #u0a198/10016 com.instagram.lite/com.facebook.lite.intent.PeriodicTaskJobService u=0 s=10198 TIME=-1h7m8s41ms:-7m8s41ms PERIODIC PERSISTED READY}
06-30 18:59:14.465  1237  1237 D JobScheduler: Error executing JobStatus{4c02f08 #u0a198/10016 com.instagram.lite/com.facebook.lite.intent.PeriodicTaskJobService u=0 s=10198 TIME=-1h7m8s83ms:-7m8s83ms PERIODIC PERSISTED READY}
06-30 18:59:14.469  1237  1237 D JobScheduler: Error executing JobStatus{4c02f08 #u0a198/10016 com.instagram.lite/com.facebook.lite.intent.PeriodicTaskJobService u=0 s=10198 TIME=-1h7m8s88ms:-7m8s88ms PERIODIC PERSISTED READY}
06-30 18:59:14.515 15702 15702 W SetupWizard: [PortalUtil] Error get Class:com.google.android.setupwizard.util.PartnerResourceS, com.google.android.setupwizard.util.PartnerResourceS
06-30 18:59:14.515 15702 15702 W SetupWizard: [PortalUtil] Error get Class:com.google.android.setupwizard.util.PartnerResourceS, com.google.android.setupwizard.util.PartnerResourceS
06-30 18:59:14.566 15120 15259 W System  : ClassLoader referenced unknown path: system/framework/mediatek-cta.jar
06-30 18:59:14.568 15120 15259 I System.out: [socket] e:java.lang.ClassNotFoundException: com.mediatek.cta.CtaUtils
06-30 18:59:14.678 15702 15728 W System  : ClassLoader referenced unknown path: /system/framework/mediatek-cta.jar
06-30 18:59:14.925  1237  1237 D JobScheduler: Error executing JobStatus{4c02f08 #u0a198/10016 com.instagram.lite/com.facebook.lite.intent.PeriodicTaskJobService u=0 s=10198 TIME=-1h7m8s543ms:-7m8s543ms PERIODIC PERSISTED READY}
06-30 18:59:15.017 15628 15652 W System  : ClassLoader referenced unknown path: /system/framework/mediatek-cta.jar
06-30 18:59:15.154 15374 15685 E SecurityDistractHooks_LibraryLoaders: Error while distracting dlopen handler: Error creating distraction: Attempted to hook a killswitched function
06-30 18:59:15.156 15374 15685 E SecurityDistractHooks_LibraryLoaders: Error while distracting android_dlopen_ext handler: Error creating distraction: Attempted to hook a killswitched function
06-30 18:59:15.156 15374 15685 E SecurityDistractHooks_MemoryAllocators: Error while distracting get_new_handler handler: Error creating distraction: Attempted to hook a killswitched function
06-30 18:59:15.157 15374 15685 E SecurityDistractHooks_MemoryAllocators: Error while distracting set_new_handler handler: Error creating distraction: Attempted to hook a killswitched function
06-30 18:59:15.351 15374 15529 E msgr.msys: E[D db_vacuum_logging]MCISQLiteLogDatabaseErrorWithFormat(81)=>Failed to get database connection or file url.: (0)(0) not an error
06-30 18:59:15.373  1237  1237 D JobScheduler: Error executing JobStatus{4c02f08 #u0a198/10016 com.instagram.lite/com.facebook.lite.intent.PeriodicTaskJobService u=0 s=10198 TIME=-1h7m8s991ms:-7m8s991ms PERIODIC PERSISTED READY}
06-30 18:59:15.499 15374 15460 E msgr.[rtc]PytorchModelLoadManager: Error downloading model rtc_automos_ns: Device does not support ExecuTorch (ART package missing)
06-30 18:59:18.101 15628 15628 I ExoPlayerImpl: Init 737d32f [AndroidXMedia3/1.10.1] [TECNO-LD7, TECNO LD7, TECNO MOBILE LIMITED, 29]
06-30 18:59:18.132 15628 15628 I ExoPlayerImpl: Init e85fc1a [AndroidXMedia3/1.10.1] [TECNO-LD7, TECNO LD7, TECNO MOBILE LIMITED, 29]
06-30 18:59:20.023 15374 15511 E msgr.msys: E[N 1283]errorHandlerDispatched(198)=>262/1283/3347/-1
06-30 18:59:20.024 15374 15511 E msgr.msys: E[N WA]_WCCXMPPStreamDisconnectHandler(344)=>xmpp/disconnect - WCIStreamStateErrorCode: 2, domain: WCIStreamState, subdomain: MCCWDGWStream: Error Domain=WCIStreamState Code=2 UserInfo=0x723ca33340 {MCFErrorDirectUnderlyingErrorKey=0x728963cd30 "Error Domain=MCCWDGWStream Code=0 UserInfo=0x723ca33240 {MCFErrorDirectLocalizedFailureReasonKey=TRANSIENT:connect_timeout}"}
06-30 18:59:21.433   492  1012 W DeviceHAL: Error from HAL Device in function get_mic_mute: Function not implemented
06-30 18:59:21.435   492  1012 W DeviceHAL: Error from HAL Device in function get_mic_mute: Function not implemented
06-30 18:59:21.706 14586 14659 W System  : ClassLoader referenced unknown path: system/framework/mediatek-cta.jar
06-30 18:59:21.707 14586 14659 I System.out: [okhttp] e:java.lang.ClassNotFoundException: com.mediatek.cta.CtaUtils
06-30 18:59:23.209   643 15924 D DropBoxManager: service->add returned No error
06-30 18:59:23.282 15374 15529 E msgr.msys: E[D db_vacuum_logging]MCISQLiteLogDatabaseErrorWithFormat(81)=>Failed to get database connection or file url.: (0)(0) not an error
06-30 18:59:24.343  1237  1237 D JobScheduler: Error executing JobStatus{4c02f08 #u0a198/10016 com.instagram.lite/com.facebook.lite.intent.PeriodicTaskJobService u=0 s=10198 TIME=-1h7m17s961ms:-7m17s961ms PERIODIC PERSISTED READY}
06-30 18:59:25.271 15879 15897 W System  : ClassLoader referenced unknown path: system/framework/mediatek-cta.jar
06-30 18:59:25.271 15879 15897 I System.out: [socket] e:java.lang.ClassNotFoundException: com.mediatek.cta.CtaUtils
06-30 18:59:25.526 15628 15956 W System  : ClassLoader referenced unknown path: system/framework/mediatek-cta.jar
06-30 18:59:25.526 15628 15956 I System.out: [socket] e:java.lang.ClassNotFoundException: com.mediatek.cta.CtaUtils
06-30 18:59:26.480 15628 15674 W nbv     : Cancelling the stream because of internal error
06-30 18:59:26.733 14586 14659 W System  : ClassLoader referenced unknown path: system/framework/mediatek-cta.jar
06-30 18:59:26.734 14586 14659 I System.out: [socket] e:java.lang.ClassNotFoundException: com.mediatek.cta.CtaUtils
```

---

## Analyse automatique

| Motif | Trouvé ? |
|---|---|
| Erreur ExoPlayer | Non |
| Erreur MediaCodec | Non |
| OMX/MediaTek | Oui |
| DEBUG-PREVIEW ERROR | Non |
| CRASH/FATAL | Non |
| ANR | Oui |
| Vidéo initialisée OK | Non |

---

## Remarque

Ce rapport est basé sur les logs capturés. L'observation visuelle finale (duration affichée, crash visible) doit être confirmée par l'utilisateur.

---

**Fin du rapport device.**
