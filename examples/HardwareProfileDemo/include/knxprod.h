#pragma once


#define paramDelay(time) (uint32_t)( \
            (time & 0xC000) == 0xC000 ? (time & 0x3FFF) * 100 : \
            (time & 0xC000) == 0x0000 ? (time & 0x3FFF) * 1000 : \
            (time & 0xC000) == 0x4000 ? (time & 0x3FFF) * 60000 : \
            (time & 0xC000) == 0x8000 ? ((time & 0x3FFF) > 1000 ? 3600000 : \
                                         (time & 0x3FFF) * 3600000 ) : 0 )
                                             
#define ETS_ModuleId_NONE 0
#define ETS_ModuleId_BASE 1
#define ETS_ModuleId_UCT 2
#define ETS_ModuleId_HWP 3
#define ETS_ModuleId_DEMO 4
#define ETS_ModuleId_HWPDEV 5
#define MAIN_FirmwareName "OpenKNX Hardware-Profil Demo"
#define MAIN_OpenKnxId 0xAD
#define MAIN_ApplicationNumber 240
#define MAIN_ApplicationVersion 25
#define MAIN_ApplicationEncoding iso-8859-15
#define MAIN_ParameterSize 189
#define MAIN_MaxKoNumber 106
#define MAIN_OrderNumber "HWProfileDemo"
#define BASE_ModuleVersion 32
#define UCT_ModuleVersion 6
// Parameter with single occurrence


#define BASE_StartupDelayBase                     0      // 2 Bits, Bit 7-6
#define     BASE_StartupDelayBaseMask 0xC0
#define     BASE_StartupDelayBaseShift 6
#define BASE_StartupDelayTime                     0      // 14 Bits, Bit 13-0
#define     BASE_StartupDelayTimeMask 0x3FFF
#define     BASE_StartupDelayTimeShift 0
#define BASE_HeartbeatDelayBase                   2      // 2 Bits, Bit 7-6
#define     BASE_HeartbeatDelayBaseMask 0xC0
#define     BASE_HeartbeatDelayBaseShift 6
#define BASE_HeartbeatDelayTime                   2      // 14 Bits, Bit 13-0
#define     BASE_HeartbeatDelayTimeMask 0x3FFF
#define     BASE_HeartbeatDelayTimeShift 0
#define BASE_Timezone                             4      // 5 Bits, Bit 7-3
#define     BASE_TimezoneMask 0xF8
#define     BASE_TimezoneShift 3
#define BASE_CombinedTimeDate                     4      // 1 Bit, Bit 2
#define     BASE_CombinedTimeDateMask 0x04
#define     BASE_CombinedTimeDateShift 2
#define BASE_SummertimeAll                        4      // 2 Bits, Bit 1-0
#define     BASE_SummertimeAllMask 0x03
#define     BASE_SummertimeAllShift 0
#define BASE_SummertimeDE                         4      // 2 Bits, Bit 1-0
#define     BASE_SummertimeDEMask 0x03
#define     BASE_SummertimeDEShift 0
#define BASE_SummertimeWorld                      4      // 2 Bits, Bit 1-0
#define     BASE_SummertimeWorldMask 0x03
#define     BASE_SummertimeWorldShift 0
#define BASE_SummertimeKO                         4      // 2 Bits, Bit 1-0
#define     BASE_SummertimeKOMask 0x03
#define     BASE_SummertimeKOShift 0
#define BASE_TimezoneCustom                       5      // char*, 63 Byte
#define     BASE_TimezoneCustomLength 63
#define BASE_Latitude                            69      // float (4 Byte)
#define BASE_Longitude                           73      // float (4 Byte)
#define BASE_Diagnose                            78      // 1 Bit, Bit 7
#define     BASE_DiagnoseMask 0x80
#define     BASE_DiagnoseShift 7
#define BASE_Watchdog                            78      // 1 Bit, Bit 6
#define     BASE_WatchdogMask 0x40
#define     BASE_WatchdogShift 6
#define BASE_ReadTimeDate                        78      // 1 Bit, Bit 5
#define     BASE_ReadTimeDateMask 0x20
#define     BASE_ReadTimeDateShift 5
#define BASE_HeartbeatExtended                   78      // 1 Bit, Bit 4
#define     BASE_HeartbeatExtendedMask 0x10
#define     BASE_HeartbeatExtendedShift 4
#define BASE_InternalTime                        78      // 1 Bit, Bit 3
#define     BASE_InternalTimeMask 0x08
#define     BASE_InternalTimeShift 3
#define BASE_ManualSave                          78      // 3 Bits, Bit 2-0
#define     BASE_ManualSaveMask 0x07
#define     BASE_ManualSaveShift 0
#define BASE_PeriodicSave                        79      // 8 Bits, Bit 7-0
#define BASE_Info1LedFunc                        80      // 16 Bits, Bit 15-0
#define BASE_Info2LedFunc                        82      // 16 Bits, Bit 15-0
#define BASE_Info3LedFunc                        84      // 16 Bits, Bit 15-0
#define BASE_DefaultLedFunc                      86      // 1 Bit, Bit 7
#define     BASE_DefaultLedFuncMask 0x80
#define     BASE_DefaultLedFuncShift 7
#define BASE_Dummy                               109      // uint8_t
#define BASE_ModuleEnabled_UCT                   110      // 1 Bit, Bit 6
#define     BASE_ModuleEnabled_UCTMask 0x40
#define     BASE_ModuleEnabled_UCTShift 6
#define BASE_ModuleEnabled_HWP                   110      // 1 Bit, Bit 5
#define     BASE_ModuleEnabled_HWPMask 0x20
#define     BASE_ModuleEnabled_HWPShift 5
#define BASE_ModuleEnabled_DEMO                  110      // 1 Bit, Bit 4
#define     BASE_ModuleEnabled_DEMOMask 0x10
#define     BASE_ModuleEnabled_DEMOShift 4
#define BASE_ModuleEnabled_HWPDEV                110      // 1 Bit, Bit 3
#define     BASE_ModuleEnabled_HWPDEVMask 0x08
#define     BASE_ModuleEnabled_HWPDEVShift 3

// Zeitbasis
#define ParamBASE_StartupDelayBase                    ((knx.paramByte(BASE_StartupDelayBase) & BASE_StartupDelayBaseMask) >> BASE_StartupDelayBaseShift)
// Zeit
#define ParamBASE_StartupDelayTime                    (knx.paramWord(BASE_StartupDelayTime) & BASE_StartupDelayTimeMask)
// Zeit (in Millisekunden)
#define ParamBASE_StartupDelayTimeMS                  (paramDelay(knx.paramWord(BASE_StartupDelayTime)))
// Zeitbasis
#define ParamBASE_HeartbeatDelayBase                  ((knx.paramByte(BASE_HeartbeatDelayBase) & BASE_HeartbeatDelayBaseMask) >> BASE_HeartbeatDelayBaseShift)
// Zeit
#define ParamBASE_HeartbeatDelayTime                  (knx.paramWord(BASE_HeartbeatDelayTime) & BASE_HeartbeatDelayTimeMask)
// Zeit (in Millisekunden)
#define ParamBASE_HeartbeatDelayTimeMS                (paramDelay(knx.paramWord(BASE_HeartbeatDelayTime)))
// Zeitzone
#define ParamBASE_Timezone                            ((knx.paramByte(BASE_Timezone) & BASE_TimezoneMask) >> BASE_TimezoneShift)
// Empfangen über
#define ParamBASE_CombinedTimeDate                    ((bool)(knx.paramByte(BASE_CombinedTimeDate) & BASE_CombinedTimeDateMask))
// Sommerzeit ermitteln durch
#define ParamBASE_SummertimeAll                       (knx.paramByte(BASE_SummertimeAll) & BASE_SummertimeAllMask)
// Sommerzeit ermitteln durch
#define ParamBASE_SummertimeDE                        (knx.paramByte(BASE_SummertimeDE) & BASE_SummertimeDEMask)
// Sommerzeit ermitteln durch
#define ParamBASE_SummertimeWorld                     (knx.paramByte(BASE_SummertimeWorld) & BASE_SummertimeWorldMask)
// Sommerzeit ermitteln durch
#define ParamBASE_SummertimeKO                        (knx.paramByte(BASE_SummertimeKO) & BASE_SummertimeKOMask)
// POSIX TZ-String
#define ParamBASE_TimezoneCustom                      (knx.paramData(BASE_TimezoneCustom))
#define ParamBASE_TimezoneCustomStr                   (knx.paramString(BASE_TimezoneCustom, BASE_TimezoneCustomLength))
// Breitengrad
#define ParamBASE_Latitude                            (knx.paramFloat(BASE_Latitude, Float_Enc_IEEE754Single))
// Längengrad
#define ParamBASE_Longitude                           (knx.paramFloat(BASE_Longitude, Float_Enc_IEEE754Single))
// Diagnoseobjekt anzeigen
#define ParamBASE_Diagnose                            ((bool)(knx.paramByte(BASE_Diagnose) & BASE_DiagnoseMask))
// Watchdog aktivieren
#define ParamBASE_Watchdog                            ((bool)(knx.paramByte(BASE_Watchdog) & BASE_WatchdogMask))
// Bei Neustart vom Bus lesen
#define ParamBASE_ReadTimeDate                        ((bool)(knx.paramByte(BASE_ReadTimeDate) & BASE_ReadTimeDateMask))
// Erweitertes "In Betrieb"
#define ParamBASE_HeartbeatExtended                   ((bool)(knx.paramByte(BASE_HeartbeatExtended) & BASE_HeartbeatExtendedMask))
// InternalTime
#define ParamBASE_InternalTime                        ((bool)(knx.paramByte(BASE_InternalTime) & BASE_InternalTimeMask))
// Manuelles speichern
#define ParamBASE_ManualSave                          (knx.paramByte(BASE_ManualSave) & BASE_ManualSaveMask)
// Zyklisches speichern
#define ParamBASE_PeriodicSave                        (knx.paramByte(BASE_PeriodicSave))
// Info1
#define ParamBASE_Info1LedFunc                        (knx.paramWord(BASE_Info1LedFunc))
// Info2
#define ParamBASE_Info2LedFunc                        (knx.paramWord(BASE_Info2LedFunc))
// Info3
#define ParamBASE_Info3LedFunc                        (knx.paramWord(BASE_Info3LedFunc))
// 
#define ParamBASE_DefaultLedFunc                      ((bool)(knx.paramByte(BASE_DefaultLedFunc) & BASE_DefaultLedFuncMask))
// 
#define ParamBASE_Dummy                               (knx.paramByte(BASE_Dummy))
// UCT
#define ParamBASE_ModuleEnabled_UCT                   ((bool)(knx.paramByte(BASE_ModuleEnabled_UCT) & BASE_ModuleEnabled_UCTMask))
// HWP
#define ParamBASE_ModuleEnabled_HWP                   ((bool)(knx.paramByte(BASE_ModuleEnabled_HWP) & BASE_ModuleEnabled_HWPMask))
// DEMO
#define ParamBASE_ModuleEnabled_DEMO                  ((bool)(knx.paramByte(BASE_ModuleEnabled_DEMO) & BASE_ModuleEnabled_DEMOMask))
// HWPDEV
#define ParamBASE_ModuleEnabled_HWPDEV                ((bool)(knx.paramByte(BASE_ModuleEnabled_HWPDEV) & BASE_ModuleEnabled_HWPDEVMask))

#define BASE_KoHeartbeat 1
#define BASE_KoTime 2
#define BASE_KoDate 3
#define BASE_KoDateTime 4
#define BASE_KoIsSummertime 5
#define BASE_KoManualSave 6
#define BASE_KoDiagnose 7

// In Betrieb
#define KoBASE_Heartbeat                           (knx.getGroupObject(BASE_KoHeartbeat))
// Uhrzeit
#define KoBASE_Time                                (knx.getGroupObject(BASE_KoTime))
// Datum
#define KoBASE_Date                                (knx.getGroupObject(BASE_KoDate))
// Uhrzeit/Datum
#define KoBASE_DateTime                            (knx.getGroupObject(BASE_KoDateTime))
// Sommerzeit aktiv
#define KoBASE_IsSummertime                        (knx.getGroupObject(BASE_KoIsSummertime))
// Speichern
#define KoBASE_ManualSave                          (knx.getGroupObject(BASE_KoManualSave))
// Diagnose
#define KoBASE_Diagnose                            (knx.getGroupObject(BASE_KoDiagnose))



#define HWP_HardwareSelect                      114      // 16 Bits, Bit 15-0
#define HWP_Pin1B3                              116      // 8 Bits, Bit 7-0
#define HWP_Pin1B4                              116      // 8 Bits, Bit 7-0
#define HWP_Pin1B2                              116      // 8 Bits, Bit 7-0
#define HWP_Pin1B5                              116      // 8 Bits, Bit 7-0
#define HWP_Pin1B0                              116      // 8 Bits, Bit 7-0
#define HWP_Pin1B1                              116      // 8 Bits, Bit 7-0
#define HWP_Pin1B7                              116      // 8 Bits, Bit 7-0
#define HWP_Pin1B6                              116      // 8 Bits, Bit 7-0
#define HWP_Pin1B8                              116      // 8 Bits, Bit 7-0
#define HWP_Pin1B9                              116      // 8 Bits, Bit 7-0
#define HWP_Pin1B10                             116      // 8 Bits, Bit 7-0
#define HWP_Pin1B11                             116      // 8 Bits, Bit 7-0
#define HWP_Pin1B12                             116      // 8 Bits, Bit 7-0
#define HWP_Pin1B13                             116      // 8 Bits, Bit 7-0
#define HWP_Pin1B14                             116      // 8 Bits, Bit 7-0
#define HWP_Pin1B15                             116      // 8 Bits, Bit 7-0
#define HWP_Pin2B3                              117      // 8 Bits, Bit 7-0
#define HWP_Pin2B4                              117      // 8 Bits, Bit 7-0
#define HWP_Pin2B2                              117      // 8 Bits, Bit 7-0
#define HWP_Pin2B5                              117      // 8 Bits, Bit 7-0
#define HWP_Pin2B0                              117      // 8 Bits, Bit 7-0
#define HWP_Pin2B1                              117      // 8 Bits, Bit 7-0
#define HWP_Pin2B7                              117      // 8 Bits, Bit 7-0
#define HWP_Pin2B6                              117      // 8 Bits, Bit 7-0
#define HWP_Pin2B8                              117      // 8 Bits, Bit 7-0
#define HWP_Pin2B9                              117      // 8 Bits, Bit 7-0
#define HWP_Pin2B10                             117      // 8 Bits, Bit 7-0
#define HWP_Pin2B11                             117      // 8 Bits, Bit 7-0
#define HWP_Pin2B12                             117      // 8 Bits, Bit 7-0
#define HWP_Pin2B13                             117      // 8 Bits, Bit 7-0
#define HWP_Pin2B14                             117      // 8 Bits, Bit 7-0
#define HWP_Pin2B15                             117      // 8 Bits, Bit 7-0
#define HWP_SensorModuleOn                      118      // 1 Bit, Bit 7
#define     HWP_SensorModuleOnMask 0x80
#define     HWP_SensorModuleOnShift 7

// Gerätetyp
#define ParamHWP_HardwareSelect                      (knx.paramWord(HWP_HardwareSelect))
// Freier Anschluss 1
#define ParamHWP_Pin1B3                              (knx.paramByte(HWP_Pin1B3))
// Freier Anschluss 1
#define ParamHWP_Pin1B4                              (knx.paramByte(HWP_Pin1B4))
// Freier Anschluss 1
#define ParamHWP_Pin1B2                              (knx.paramByte(HWP_Pin1B2))
// Freier Anschluss 1
#define ParamHWP_Pin1B5                              (knx.paramByte(HWP_Pin1B5))
// Freier Anschluss 1
#define ParamHWP_Pin1B0                              (knx.paramByte(HWP_Pin1B0))
// Freier Anschluss 1
#define ParamHWP_Pin1B1                              (knx.paramByte(HWP_Pin1B1))
// Freier Anschluss 1
#define ParamHWP_Pin1B7                              (knx.paramByte(HWP_Pin1B7))
// Freier Anschluss 1
#define ParamHWP_Pin1B6                              (knx.paramByte(HWP_Pin1B6))
// Freier Anschluss 1
#define ParamHWP_Pin1B8                              (knx.paramByte(HWP_Pin1B8))
// Freier Anschluss 1
#define ParamHWP_Pin1B9                              (knx.paramByte(HWP_Pin1B9))
// Freier Anschluss 1
#define ParamHWP_Pin1B10                             (knx.paramByte(HWP_Pin1B10))
// Freier Anschluss 1
#define ParamHWP_Pin1B11                             (knx.paramByte(HWP_Pin1B11))
// Freier Anschluss 1
#define ParamHWP_Pin1B12                             (knx.paramByte(HWP_Pin1B12))
// Freier Anschluss 1
#define ParamHWP_Pin1B13                             (knx.paramByte(HWP_Pin1B13))
// Freier Anschluss 1
#define ParamHWP_Pin1B14                             (knx.paramByte(HWP_Pin1B14))
// Freier Anschluss 1
#define ParamHWP_Pin1B15                             (knx.paramByte(HWP_Pin1B15))
// Freier Anschluss 2
#define ParamHWP_Pin2B3                              (knx.paramByte(HWP_Pin2B3))
// Freier Anschluss 2
#define ParamHWP_Pin2B4                              (knx.paramByte(HWP_Pin2B4))
// Freier Anschluss 2
#define ParamHWP_Pin2B2                              (knx.paramByte(HWP_Pin2B2))
// Freier Anschluss 2
#define ParamHWP_Pin2B5                              (knx.paramByte(HWP_Pin2B5))
// Freier Anschluss 2
#define ParamHWP_Pin2B0                              (knx.paramByte(HWP_Pin2B0))
// Freier Anschluss 2
#define ParamHWP_Pin2B1                              (knx.paramByte(HWP_Pin2B1))
// Freier Anschluss 2
#define ParamHWP_Pin2B7                              (knx.paramByte(HWP_Pin2B7))
// Freier Anschluss 2
#define ParamHWP_Pin2B6                              (knx.paramByte(HWP_Pin2B6))
// Freier Anschluss 2
#define ParamHWP_Pin2B8                              (knx.paramByte(HWP_Pin2B8))
// Freier Anschluss 2
#define ParamHWP_Pin2B9                              (knx.paramByte(HWP_Pin2B9))
// Freier Anschluss 2
#define ParamHWP_Pin2B10                             (knx.paramByte(HWP_Pin2B10))
// Freier Anschluss 2
#define ParamHWP_Pin2B11                             (knx.paramByte(HWP_Pin2B11))
// Freier Anschluss 2
#define ParamHWP_Pin2B12                             (knx.paramByte(HWP_Pin2B12))
// Freier Anschluss 2
#define ParamHWP_Pin2B13                             (knx.paramByte(HWP_Pin2B13))
// Freier Anschluss 2
#define ParamHWP_Pin2B14                             (knx.paramByte(HWP_Pin2B14))
// Freier Anschluss 2
#define ParamHWP_Pin2B15                             (knx.paramByte(HWP_Pin2B15))
// aktiv
#define ParamHWP_SensorModuleOn                      ((bool)(knx.paramByte(HWP_SensorModuleOn) & HWP_SensorModuleOnMask))

#define DEMO_LanDhcp                             119      // 8 Bits, Bit 7-0
#define DEMO_WifiSsid                            120      // char*, 32 Byte
#define     DEMO_WifiSsidLength 32
#define DEMO_DisplayBrightness                   152      // uint8_t
#define DEMO_BuzzerVolume                        153      // 8 Bits, Bit 7-0
#define DEMO_Input1                              154      // 8 Bits, Bit 7-0
#define DEMO_Input2                              155      // 8 Bits, Bit 7-0
#define DEMO_Input3                              156      // 8 Bits, Bit 7-0
#define DEMO_Input4                              157      // 8 Bits, Bit 7-0
#define DEMO_Logger                              158      // 8 Bits, Bit 7-0
#define DEMO_BiUsedR0                            159      // 8 Bits, Bit 7-0
#define DEMO_BiUsedR1                            159      // 8 Bits, Bit 7-0
#define DEMO_BiUsedR2                            159      // 8 Bits, Bit 7-0
#define DEMO_BiUsedR4                            159      // 8 Bits, Bit 7-0
#define DEMO_LedsR0                              160      // 8 Bits, Bit 7-0
#define DEMO_LedsR2                              160      // 8 Bits, Bit 7-0
#define DEMO_LedsR4                              160      // 8 Bits, Bit 7-0
#define DEMO_PowerSend                           163      // 8 Bits, Bit 7-0
#define DEMO_TempSend                            164      // 8 Bits, Bit 7-0
#define DEMO_FrontLock                           165      // 8 Bits, Bit 7-0
#define DEMO_TempHumSend                         166      // 8 Bits, Bit 7-0
#define DEMO_Co2Send                             167      // 8 Bits, Bit 7-0
#define DEMO_LuxSend                             168      // 8 Bits, Bit 7-0
#define DEMO_PresenceDelay                       169      // uint8_t
#define DEMO_ModuleSend                          170      // 8 Bits, Bit 7-0
#define DEMO_Shutter                             171      // 8 Bits, Bit 7-0
#define DEMO_Channel1                            172      // 8 Bits, Bit 7-0
#define DEMO_Channel2                            173      // 8 Bits, Bit 7-0
#define DEMO_Channel3                            174      // 8 Bits, Bit 7-0
#define DEMO_Channel4                            175      // 8 Bits, Bit 7-0
#define DEMO_RelUsedR0                           161      // 8 Bits, Bit 7-0
#define DEMO_RelUsedR1                           161      // 8 Bits, Bit 7-0
#define DEMO_RelUsedR2                           161      // 8 Bits, Bit 7-0
#define DEMO_ChannelsR0                          162      // 8 Bits, Bit 7-0
#define DEMO_ChannelsR1                          162      // 8 Bits, Bit 7-0
#define DEMO_ChannelsR2                          162      // 8 Bits, Bit 7-0
#define DEMO_Outputs                             176      // 8 Bits, Bit 7-0
#define DEMO_Out1Signal                          177      // 8 Bits, Bit 7-0
#define DEMO_Out2Signal                          178      // 8 Bits, Bit 7-0
#define DEMO_Out1DataB3                          179      // 8 Bits, Bit 7-0
#define DEMO_Out1DataB4                          179      // 8 Bits, Bit 7-0
#define DEMO_Out1DataB2                          179      // 8 Bits, Bit 7-0
#define DEMO_Out1DataB5                          179      // 8 Bits, Bit 7-0
#define DEMO_Out1DataB0                          179      // 8 Bits, Bit 7-0
#define DEMO_Out1DataB1                          179      // 8 Bits, Bit 7-0
#define DEMO_Out1DataB7                          179      // 8 Bits, Bit 7-0
#define DEMO_Out1DataB6                          179      // 8 Bits, Bit 7-0
#define DEMO_Out1DataB8                          179      // 8 Bits, Bit 7-0
#define DEMO_Out1DataB9                          179      // 8 Bits, Bit 7-0
#define DEMO_Out1DataB10                         179      // 8 Bits, Bit 7-0
#define DEMO_Out1DataB11                         179      // 8 Bits, Bit 7-0
#define DEMO_Out1DataB12                         179      // 8 Bits, Bit 7-0
#define DEMO_Out1DataB13                         179      // 8 Bits, Bit 7-0
#define DEMO_Out1DataB14                         179      // 8 Bits, Bit 7-0
#define DEMO_Out1DataB15                         179      // 8 Bits, Bit 7-0
#define DEMO_Out1ClockB3                         180      // 8 Bits, Bit 7-0
#define DEMO_Out1ClockB4                         180      // 8 Bits, Bit 7-0
#define DEMO_Out1ClockB2                         180      // 8 Bits, Bit 7-0
#define DEMO_Out1ClockB5                         180      // 8 Bits, Bit 7-0
#define DEMO_Out1ClockB0                         180      // 8 Bits, Bit 7-0
#define DEMO_Out1ClockB1                         180      // 8 Bits, Bit 7-0
#define DEMO_Out1ClockB7                         180      // 8 Bits, Bit 7-0
#define DEMO_Out1ClockB6                         180      // 8 Bits, Bit 7-0
#define DEMO_Out1ClockB8                         180      // 8 Bits, Bit 7-0
#define DEMO_Out1ClockB9                         180      // 8 Bits, Bit 7-0
#define DEMO_Out1ClockB10                        180      // 8 Bits, Bit 7-0
#define DEMO_Out1ClockB11                        180      // 8 Bits, Bit 7-0
#define DEMO_Out1ClockB12                        180      // 8 Bits, Bit 7-0
#define DEMO_Out1ClockB13                        180      // 8 Bits, Bit 7-0
#define DEMO_Out1ClockB14                        180      // 8 Bits, Bit 7-0
#define DEMO_Out1ClockB15                        180      // 8 Bits, Bit 7-0
#define DEMO_Out2DataB3                          181      // 8 Bits, Bit 7-0
#define DEMO_Out2DataB4                          181      // 8 Bits, Bit 7-0
#define DEMO_Out2DataB2                          181      // 8 Bits, Bit 7-0
#define DEMO_Out2DataB5                          181      // 8 Bits, Bit 7-0
#define DEMO_Out2DataB0                          181      // 8 Bits, Bit 7-0
#define DEMO_Out2DataB1                          181      // 8 Bits, Bit 7-0
#define DEMO_Out2DataB7                          181      // 8 Bits, Bit 7-0
#define DEMO_Out2DataB6                          181      // 8 Bits, Bit 7-0
#define DEMO_Out2DataB8                          181      // 8 Bits, Bit 7-0
#define DEMO_Out2DataB9                          181      // 8 Bits, Bit 7-0
#define DEMO_Out2DataB10                         181      // 8 Bits, Bit 7-0
#define DEMO_Out2DataB11                         181      // 8 Bits, Bit 7-0
#define DEMO_Out2DataB12                         181      // 8 Bits, Bit 7-0
#define DEMO_Out2DataB13                         181      // 8 Bits, Bit 7-0
#define DEMO_Out2DataB14                         181      // 8 Bits, Bit 7-0
#define DEMO_Out2DataB15                         181      // 8 Bits, Bit 7-0
#define DEMO_Out2ClockB3                         182      // 8 Bits, Bit 7-0
#define DEMO_Out2ClockB4                         182      // 8 Bits, Bit 7-0
#define DEMO_Out2ClockB2                         182      // 8 Bits, Bit 7-0
#define DEMO_Out2ClockB5                         182      // 8 Bits, Bit 7-0
#define DEMO_Out2ClockB0                         182      // 8 Bits, Bit 7-0
#define DEMO_Out2ClockB1                         182      // 8 Bits, Bit 7-0
#define DEMO_Out2ClockB7                         182      // 8 Bits, Bit 7-0
#define DEMO_Out2ClockB6                         182      // 8 Bits, Bit 7-0
#define DEMO_Out2ClockB8                         182      // 8 Bits, Bit 7-0
#define DEMO_Out2ClockB9                         182      // 8 Bits, Bit 7-0
#define DEMO_Out2ClockB10                        182      // 8 Bits, Bit 7-0
#define DEMO_Out2ClockB11                        182      // 8 Bits, Bit 7-0
#define DEMO_Out2ClockB12                        182      // 8 Bits, Bit 7-0
#define DEMO_Out2ClockB13                        182      // 8 Bits, Bit 7-0
#define DEMO_Out2ClockB14                        182      // 8 Bits, Bit 7-0
#define DEMO_Out2ClockB15                        182      // 8 Bits, Bit 7-0
#define DEMO_Out1DataGpio                        183      // uint8_t
#define DEMO_Out1MosiGpio                        184      // uint8_t
#define DEMO_Out1ClockGpio                       185      // uint8_t
#define DEMO_Out2DataGpio                        186      // uint8_t
#define DEMO_Out2MosiGpio                        187      // uint8_t
#define DEMO_Out2ClockGpio                       188      // uint8_t

// IP-Adresse per DHCP
#define ParamDEMO_LanDhcp                             (knx.paramByte(DEMO_LanDhcp))
// WLAN-Name (SSID)
#define ParamDEMO_WifiSsid                            (knx.paramData(DEMO_WifiSsid))
#define ParamDEMO_WifiSsidStr                         (knx.paramString(DEMO_WifiSsid, DEMO_WifiSsidLength))
// Display-Helligkeit
#define ParamDEMO_DisplayBrightness                   (knx.paramByte(DEMO_DisplayBrightness))
// Lautstärke Summer
#define ParamDEMO_BuzzerVolume                        (knx.paramByte(DEMO_BuzzerVolume))
// Eingang 1
#define ParamDEMO_Input1                              (knx.paramByte(DEMO_Input1))
// Eingang 2
#define ParamDEMO_Input2                              (knx.paramByte(DEMO_Input2))
// Eingang 3
#define ParamDEMO_Input3                              (knx.paramByte(DEMO_Input3))
// Eingang 4
#define ParamDEMO_Input4                              (knx.paramByte(DEMO_Input4))
// Messwerte im Flash aufzeichnen
#define ParamDEMO_Logger                              (knx.paramByte(DEMO_Logger))
// Genutzte Binäreingänge
#define ParamDEMO_BiUsedR0                            (knx.paramByte(DEMO_BiUsedR0))
// Genutzte Binäreingänge
#define ParamDEMO_BiUsedR1                            (knx.paramByte(DEMO_BiUsedR1))
// Genutzte Binäreingänge
#define ParamDEMO_BiUsedR2                            (knx.paramByte(DEMO_BiUsedR2))
// Genutzte Binäreingänge
#define ParamDEMO_BiUsedR4                            (knx.paramByte(DEMO_BiUsedR4))
// Status-LEDs
#define ParamDEMO_LedsR0                              (knx.paramByte(DEMO_LedsR0))
// Status-LEDs
#define ParamDEMO_LedsR2                              (knx.paramByte(DEMO_LedsR2))
// Status-LEDs
#define ParamDEMO_LedsR4                              (knx.paramByte(DEMO_LedsR4))
// Leistung senden
#define ParamDEMO_PowerSend                           (knx.paramByte(DEMO_PowerSend))
// Gerätetemperatur senden
#define ParamDEMO_TempSend                            (knx.paramByte(DEMO_TempSend))
// Frontbedienung sperren
#define ParamDEMO_FrontLock                           (knx.paramByte(DEMO_FrontLock))
// Temperatur/Feuchte senden
#define ParamDEMO_TempHumSend                         (knx.paramByte(DEMO_TempHumSend))
// CO2 senden
#define ParamDEMO_Co2Send                             (knx.paramByte(DEMO_Co2Send))
// Helligkeit senden
#define ParamDEMO_LuxSend                             (knx.paramByte(DEMO_LuxSend))
// Nachlaufzeit Präsenz (min)
#define ParamDEMO_PresenceDelay                       (knx.paramByte(DEMO_PresenceDelay))
// Werte des Steckmoduls senden
#define ParamDEMO_ModuleSend                          (knx.paramByte(DEMO_ModuleSend))
// Kanäle 1 und 2 als Jalousie
#define ParamDEMO_Shutter                             (knx.paramByte(DEMO_Shutter))
// Schaltkanal 1
#define ParamDEMO_Channel1                            (knx.paramByte(DEMO_Channel1))
// Schaltkanal 2
#define ParamDEMO_Channel2                            (knx.paramByte(DEMO_Channel2))
// Schaltkanal 3
#define ParamDEMO_Channel3                            (knx.paramByte(DEMO_Channel3))
// Schaltkanal 4
#define ParamDEMO_Channel4                            (knx.paramByte(DEMO_Channel4))
// Genutzte Relais
#define ParamDEMO_RelUsedR0                           (knx.paramByte(DEMO_RelUsedR0))
// Genutzte Relais
#define ParamDEMO_RelUsedR1                           (knx.paramByte(DEMO_RelUsedR1))
// Genutzte Relais
#define ParamDEMO_RelUsedR2                           (knx.paramByte(DEMO_RelUsedR2))
// Schaltkanäle
#define ParamDEMO_ChannelsR0                          (knx.paramByte(DEMO_ChannelsR0))
// Schaltkanäle
#define ParamDEMO_ChannelsR1                          (knx.paramByte(DEMO_ChannelsR1))
// Schaltkanäle
#define ParamDEMO_ChannelsR2                          (knx.paramByte(DEMO_ChannelsR2))
// Genutzte Ausgänge
#define ParamDEMO_Outputs                             (knx.paramByte(DEMO_Outputs))
// Signal
#define ParamDEMO_Out1Signal                          (knx.paramByte(DEMO_Out1Signal))
// Signal
#define ParamDEMO_Out2Signal                          (knx.paramByte(DEMO_Out2Signal))
// Daten-Port
#define ParamDEMO_Out1DataB3                          (knx.paramByte(DEMO_Out1DataB3))
// Daten-Port
#define ParamDEMO_Out1DataB4                          (knx.paramByte(DEMO_Out1DataB4))
// Daten-Port
#define ParamDEMO_Out1DataB2                          (knx.paramByte(DEMO_Out1DataB2))
// Daten-Port
#define ParamDEMO_Out1DataB5                          (knx.paramByte(DEMO_Out1DataB5))
// Daten-Port
#define ParamDEMO_Out1DataB0                          (knx.paramByte(DEMO_Out1DataB0))
// Daten-Port
#define ParamDEMO_Out1DataB1                          (knx.paramByte(DEMO_Out1DataB1))
// Daten-Port
#define ParamDEMO_Out1DataB7                          (knx.paramByte(DEMO_Out1DataB7))
// Daten-Port
#define ParamDEMO_Out1DataB6                          (knx.paramByte(DEMO_Out1DataB6))
// Daten-Port
#define ParamDEMO_Out1DataB8                          (knx.paramByte(DEMO_Out1DataB8))
// Daten-Port
#define ParamDEMO_Out1DataB9                          (knx.paramByte(DEMO_Out1DataB9))
// Daten-Port
#define ParamDEMO_Out1DataB10                         (knx.paramByte(DEMO_Out1DataB10))
// Daten-Port
#define ParamDEMO_Out1DataB11                         (knx.paramByte(DEMO_Out1DataB11))
// Daten-Port
#define ParamDEMO_Out1DataB12                         (knx.paramByte(DEMO_Out1DataB12))
// Daten-Port
#define ParamDEMO_Out1DataB13                         (knx.paramByte(DEMO_Out1DataB13))
// Daten-Port
#define ParamDEMO_Out1DataB14                         (knx.paramByte(DEMO_Out1DataB14))
// Daten-Port
#define ParamDEMO_Out1DataB15                         (knx.paramByte(DEMO_Out1DataB15))
// Takt-Port
#define ParamDEMO_Out1ClockB3                         (knx.paramByte(DEMO_Out1ClockB3))
// Takt-Port
#define ParamDEMO_Out1ClockB4                         (knx.paramByte(DEMO_Out1ClockB4))
// Takt-Port
#define ParamDEMO_Out1ClockB2                         (knx.paramByte(DEMO_Out1ClockB2))
// Takt-Port
#define ParamDEMO_Out1ClockB5                         (knx.paramByte(DEMO_Out1ClockB5))
// Takt-Port
#define ParamDEMO_Out1ClockB0                         (knx.paramByte(DEMO_Out1ClockB0))
// Takt-Port
#define ParamDEMO_Out1ClockB1                         (knx.paramByte(DEMO_Out1ClockB1))
// Takt-Port
#define ParamDEMO_Out1ClockB7                         (knx.paramByte(DEMO_Out1ClockB7))
// Takt-Port
#define ParamDEMO_Out1ClockB6                         (knx.paramByte(DEMO_Out1ClockB6))
// Takt-Port
#define ParamDEMO_Out1ClockB8                         (knx.paramByte(DEMO_Out1ClockB8))
// Takt-Port
#define ParamDEMO_Out1ClockB9                         (knx.paramByte(DEMO_Out1ClockB9))
// Takt-Port
#define ParamDEMO_Out1ClockB10                        (knx.paramByte(DEMO_Out1ClockB10))
// Takt-Port
#define ParamDEMO_Out1ClockB11                        (knx.paramByte(DEMO_Out1ClockB11))
// Takt-Port
#define ParamDEMO_Out1ClockB12                        (knx.paramByte(DEMO_Out1ClockB12))
// Takt-Port
#define ParamDEMO_Out1ClockB13                        (knx.paramByte(DEMO_Out1ClockB13))
// Takt-Port
#define ParamDEMO_Out1ClockB14                        (knx.paramByte(DEMO_Out1ClockB14))
// Takt-Port
#define ParamDEMO_Out1ClockB15                        (knx.paramByte(DEMO_Out1ClockB15))
// Daten-Port
#define ParamDEMO_Out2DataB3                          (knx.paramByte(DEMO_Out2DataB3))
// Daten-Port
#define ParamDEMO_Out2DataB4                          (knx.paramByte(DEMO_Out2DataB4))
// Daten-Port
#define ParamDEMO_Out2DataB2                          (knx.paramByte(DEMO_Out2DataB2))
// Daten-Port
#define ParamDEMO_Out2DataB5                          (knx.paramByte(DEMO_Out2DataB5))
// Daten-Port
#define ParamDEMO_Out2DataB0                          (knx.paramByte(DEMO_Out2DataB0))
// Daten-Port
#define ParamDEMO_Out2DataB1                          (knx.paramByte(DEMO_Out2DataB1))
// Daten-Port
#define ParamDEMO_Out2DataB7                          (knx.paramByte(DEMO_Out2DataB7))
// Daten-Port
#define ParamDEMO_Out2DataB6                          (knx.paramByte(DEMO_Out2DataB6))
// Daten-Port
#define ParamDEMO_Out2DataB8                          (knx.paramByte(DEMO_Out2DataB8))
// Daten-Port
#define ParamDEMO_Out2DataB9                          (knx.paramByte(DEMO_Out2DataB9))
// Daten-Port
#define ParamDEMO_Out2DataB10                         (knx.paramByte(DEMO_Out2DataB10))
// Daten-Port
#define ParamDEMO_Out2DataB11                         (knx.paramByte(DEMO_Out2DataB11))
// Daten-Port
#define ParamDEMO_Out2DataB12                         (knx.paramByte(DEMO_Out2DataB12))
// Daten-Port
#define ParamDEMO_Out2DataB13                         (knx.paramByte(DEMO_Out2DataB13))
// Daten-Port
#define ParamDEMO_Out2DataB14                         (knx.paramByte(DEMO_Out2DataB14))
// Daten-Port
#define ParamDEMO_Out2DataB15                         (knx.paramByte(DEMO_Out2DataB15))
// Takt-Port
#define ParamDEMO_Out2ClockB3                         (knx.paramByte(DEMO_Out2ClockB3))
// Takt-Port
#define ParamDEMO_Out2ClockB4                         (knx.paramByte(DEMO_Out2ClockB4))
// Takt-Port
#define ParamDEMO_Out2ClockB2                         (knx.paramByte(DEMO_Out2ClockB2))
// Takt-Port
#define ParamDEMO_Out2ClockB5                         (knx.paramByte(DEMO_Out2ClockB5))
// Takt-Port
#define ParamDEMO_Out2ClockB0                         (knx.paramByte(DEMO_Out2ClockB0))
// Takt-Port
#define ParamDEMO_Out2ClockB1                         (knx.paramByte(DEMO_Out2ClockB1))
// Takt-Port
#define ParamDEMO_Out2ClockB7                         (knx.paramByte(DEMO_Out2ClockB7))
// Takt-Port
#define ParamDEMO_Out2ClockB6                         (knx.paramByte(DEMO_Out2ClockB6))
// Takt-Port
#define ParamDEMO_Out2ClockB8                         (knx.paramByte(DEMO_Out2ClockB8))
// Takt-Port
#define ParamDEMO_Out2ClockB9                         (knx.paramByte(DEMO_Out2ClockB9))
// Takt-Port
#define ParamDEMO_Out2ClockB10                        (knx.paramByte(DEMO_Out2ClockB10))
// Takt-Port
#define ParamDEMO_Out2ClockB11                        (knx.paramByte(DEMO_Out2ClockB11))
// Takt-Port
#define ParamDEMO_Out2ClockB12                        (knx.paramByte(DEMO_Out2ClockB12))
// Takt-Port
#define ParamDEMO_Out2ClockB13                        (knx.paramByte(DEMO_Out2ClockB13))
// Takt-Port
#define ParamDEMO_Out2ClockB14                        (knx.paramByte(DEMO_Out2ClockB14))
// Takt-Port
#define ParamDEMO_Out2ClockB15                        (knx.paramByte(DEMO_Out2ClockB15))
// Daten-GPIO
#define ParamDEMO_Out1DataGpio                        (knx.paramByte(DEMO_Out1DataGpio))
// MOSI-GPIO
#define ParamDEMO_Out1MosiGpio                        (knx.paramByte(DEMO_Out1MosiGpio))
// Takt-GPIO
#define ParamDEMO_Out1ClockGpio                       (knx.paramByte(DEMO_Out1ClockGpio))
// Daten-GPIO
#define ParamDEMO_Out2DataGpio                        (knx.paramByte(DEMO_Out2DataGpio))
// MOSI-GPIO
#define ParamDEMO_Out2MosiGpio                        (knx.paramByte(DEMO_Out2MosiGpio))
// Takt-GPIO
#define ParamDEMO_Out2ClockGpio                       (knx.paramByte(DEMO_Out2ClockGpio))

#define DEMO_KoPower 101
#define DEMO_KoDeviceTemp 102
#define DEMO_KoTempHum 103
#define DEMO_KoCo2 104
#define DEMO_KoLux 105
#define DEMO_KoPresence 106

// Leistung
#define KoDEMO_Power                               (knx.getGroupObject(DEMO_KoPower))
// Gerätetemperatur
#define KoDEMO_DeviceTemp                          (knx.getGroupObject(DEMO_KoDeviceTemp))
// Raumtemperatur
#define KoDEMO_TempHum                             (knx.getGroupObject(DEMO_KoTempHum))
// CO2
#define KoDEMO_Co2                                 (knx.getGroupObject(DEMO_KoCo2))
// Helligkeit
#define KoDEMO_Lux                                 (knx.getGroupObject(DEMO_KoLux))
// Präsenz
#define KoDEMO_Presence                            (knx.getGroupObject(DEMO_KoPresence))




// enumeration types


#ifdef MAIN_FirmwareRevision
#ifndef FIRMWARE_REVISION
#define FIRMWARE_REVISION MAIN_FirmwareRevision
#endif
#endif
#ifdef MAIN_FirmwareName
#ifndef FIRMWARE_NAME
#define FIRMWARE_NAME MAIN_FirmwareName
#endif
#endif
