#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <initguid.h>
#include <fwpmu.h>
#include <iphlpapi.h>
#pragma comment(lib, "fwpuclnt.lib")
#pragma comment(lib, "iphlpapi.lib")

// Windows SDK identifiers. Local constants also allow builds with MinGW's
// incomplete fwpmu.h without importing a different WFP ABI.
static const GUID aleAppId = {0xd78e1e87,0x8644,0x4ea5,{0x94,0x37,0xd8,0x09,0xec,0xef,0xc9,0x71}};
static const GUID localInterface = {0x4cd62a49,0x59c3,0x4969,{0xb7,0xf3,0xbd,0xa5,0xd3,0x28,0x90,0xa4}};
static const GUID conditionFlags = {0x632ce23b,0x5167,0x435c,{0x86,0xd7,0xe9,0x03,0x68,0x4a,0xa8,0x0c}};
static const GUID authConnect4 = {0xc38d57d1,0x05a7,0x4c33,{0x90,0x4f,0x7f,0xbc,0xee,0xe6,0x0e,0x82}};
static const GUID authConnect6 = {0x4a72393b,0x319f,0x44bc,{0x84,0xc3,0xba,0x54,0xdc,0xb3,0xb6,0xb4}};

// Dynamic WFP filters live only as long as the owning application. They never
// change the computer's persistent firewall policy. Non-core processes may
// use the TUN and loopback, but cannot bypass the tunnel on a physical NIC.
extern "C" __declspec(dllexport) DWORD __cdecl Vo1dGuardStart(
    const wchar_t* corePath, const wchar_t* xrayPath, ULONG tunIndex, HANDLE* result)
{
    *result = nullptr;
    NET_LUID luid{};
    DWORD error = ConvertInterfaceIndexToLuid(tunIndex, &luid);
    if (error) return error;
    FWPM_SESSION0 session{};
    session.flags = 0x00000001; // FWPM_SESSION_FLAG_DYNAMIC
    session.displayData.name = const_cast<wchar_t*>(L"VO1D VPN guard");
    HANDLE engine = nullptr;
    error = FwpmEngineOpen0(nullptr, RPC_C_AUTHN_WINNT, nullptr, &session, &engine);
    if (error) return error;
    FWP_BYTE_BLOB* appId = nullptr;
    error = FwpmGetAppIdFromFileName0(corePath, &appId);
    if (error) { FwpmEngineClose0(engine); return error; }
    FWP_BYTE_BLOB* xrayId = nullptr;
    if (xrayPath && *xrayPath) error = FwpmGetAppIdFromFileName0(xrayPath, &xrayId);
    if (error) { FwpmFreeMemory0((void**)&appId); FwpmEngineClose0(engine); return error; }
    error = FwpmTransactionBegin0(engine, 0);
    if (error) { FwpmFreeMemory0((void**)&appId); if (xrayId) FwpmFreeMemory0((void**)&xrayId); FwpmEngineClose0(engine); return error; }
    FWPM_SUBLAYER0 sub{};
    sub.subLayerKey = {0xbba23f40,0x8402,0x46a5,{0x91,0x45,0x6c,0x91,0x87,0xbc,0x35,0x10}};
    sub.displayData.name = const_cast<wchar_t*>(L"VO1D ephemeral kill switch");
    sub.weight = 0xF000;
    error = FwpmSubLayerAdd0(engine, &sub, nullptr);
    if (!error) {
        FWPM_FILTER_CONDITION0 conditions[2]{};
        conditions[0].fieldKey = localInterface;
        conditions[0].matchType = FWP_MATCH_NOT_EQUAL;
        conditions[0].conditionValue.type = FWP_UINT64;
        conditions[0].conditionValue.uint64 = &luid.Value;
        conditions[1].fieldKey = conditionFlags;
        conditions[1].matchType = FWP_MATCH_FLAGS_NONE_SET;
        conditions[1].conditionValue.type = FWP_UINT32;
        conditions[1].conditionValue.uint32 = FWP_CONDITION_FLAG_IS_LOOPBACK;
        const GUID layers[] = {authConnect4, authConnect6};
        for (const auto& layer : layers) {
            // Higher weight permits in this sublayer exempt only the two
            // protected bundled cores. Other Windows firewall rules still apply.
            FWP_BYTE_BLOB* permitted[] = {appId, xrayId};
            for (auto* id : permitted) {
                if (!id) continue;
                FWPM_FILTER_CONDITION0 app{};
                app.fieldKey = aleAppId; app.matchType = FWP_MATCH_EQUAL;
                app.conditionValue.type = FWP_BYTE_BLOB_TYPE; app.conditionValue.byteBlob = id;
                FWPM_FILTER0 allow{};
                allow.displayData.name = const_cast<wchar_t*>(L"VO1D: permit bundled transport core");
                allow.layerKey = layer; allow.subLayerKey = sub.subLayerKey;
                allow.action.type = FWP_ACTION_PERMIT;
                allow.weight.type = FWP_UINT8; allow.weight.uint8 = 16;
                allow.numFilterConditions = 1; allow.filterCondition = &app;
                error = FwpmFilterAdd0(engine, &allow, nullptr, nullptr);
                if (error) break;
            }
            if (error) break;
            FWPM_FILTER0 filter{};
            filter.displayData.name = const_cast<wchar_t*>(L"VO1D: prevent physical-interface bypass");
            filter.layerKey = layer;
            filter.subLayerKey = sub.subLayerKey;
            filter.action.type = FWP_ACTION_BLOCK;
            filter.weight.type = FWP_UINT8;
            filter.weight.uint8 = 15;
            filter.numFilterConditions = 2;
            filter.filterCondition = conditions;
            UINT64 id = 0;
            error = FwpmFilterAdd0(engine, &filter, nullptr, &id);
            if (error) break;
        }
    }
    FwpmFreeMemory0((void**)&appId);
    if (xrayId) FwpmFreeMemory0((void**)&xrayId);
    if (!error) error = FwpmTransactionCommit0(engine);
    else FwpmTransactionAbort0(engine);
    if (error) { FwpmEngineClose0(engine); return error; }
    *result = engine;
    return ERROR_SUCCESS;
}

extern "C" __declspec(dllexport) void __cdecl Vo1dGuardStop(HANDLE engine)
{
    if (engine) FwpmEngineClose0(engine);
}
