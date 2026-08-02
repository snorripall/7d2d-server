using JetBrains.Annotations;

namespace VersionEnforcer.Harmony
{
    // VersionEnforcer used to rewrite NetPackagePlayerLogin (Write/Read/GetLength)
    // to embed the mod list. That path is broken with current 7DTD v2.6 networking:
    // clients send length 2408 while servers expect ~3924, and join fails immediately.
    //
    // Leave this type present (some code may reference the namespace) but apply no
    // Harmony patches so both client and dedicated server use vanilla login packets.
    [UsedImplicitly]
    public class Harmony_NetPackagePlayerLogin
    {
    }
}
