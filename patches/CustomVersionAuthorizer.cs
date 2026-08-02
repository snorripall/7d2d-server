using JetBrains.Annotations;
using System.Collections.Generic;
using System.Linq;
using System.Xml.Linq;
namespace VersionEnforcer.Scripts
{
    [UsedImplicitly]
    public class CustomVersionAuthorizer : AuthorizerAbs
    {
        internal static readonly Dictionary<string, List<ModVersionInfo>> PlatformUserIdToProvidedCustomVersion =
            new Dictionary<string, List<ModVersionInfo>>();

        public struct ModVersionInfo
        {
            public string ModName;
            public string ModVersion;
        }

        public override int Order => 71;
        public override string AuthorizerName => "CustomVersion";
        public override string StateLocalizationKey => "authstate_customversion";

        private enum ModIssue { Missing, InvalidVersion }
        private struct ModIssues
        {
            public string ModName;
            public ModIssue Issue;
            public string ServerVersion;
            public string ClientVersion;
        }

        private readonly List<string> ignoreList = new List<string>();
        private const int MAX_MESSAGE_LENGTH = 200;

        public override void Init(IAuthorizationResponses _authResponsesHandler)
        {
            base.Init(_authResponsesHandler);
            LoadIgnoreList();
        }

        public override (EAuthorizerSyncResult, GameUtils.KickPlayerData?) Authorize(ClientInfo _clientInfo)
        {
            // Always allow. The companion NetPackagePlayerLogin rewrite that
            // delivered the client mod list is disabled on 7DTD v2.6 (it caused
            // 2408 vs ~3924 packet size mismatches). Without that payload every
            // join looked like "all mods missing" and was kicked here.
            PlatformUserIdToProvidedCustomVersion.Remove(
                _clientInfo.PlatformId.ReadablePlatformUserIdentifier);
            return (EAuthorizerSyncResult.SyncAllow, null);
        }

        private void LoadIgnoreList()
        {
            var filename = "IgnoreList.xml";
            var xmlFile = new XmlFile(ModManager.GetMod("zzz_REBIRTH__Utils", true).Path, filename);
            XElement root = xmlFile.XmlDoc.Root;
            if (root == null)
            {
                Log.Error($"{Globals.LOG_TAG} {filename} not found or no XML root");
                return;
            }

            foreach (XElement elem in root.Elements("mod"))
            {
                string modName = elem.Attribute("name")?.Value ?? "";
                if (modName.Length > 0) ignoreList.Add(modName);
            }
        }
    }
}