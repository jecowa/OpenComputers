/**
 * This API provides interfaces and factory methods for the OpenComputers mod.
 * <p/>
 * There are several parts to this API:
 * <dl>
 * <dt>The {@link Driver} API</dt>
 * <dd>
 * This API is used to provide glue code to the mod that allows it to interact
 * with foreign objects. You need a driver if you wish to connect some object
 * to the internal {@link li.cil.oc.api.network.Network}, for example because
 * you wish to interact with other blocks / components of the mod. The most
 * typical scenario for this will be adding a new object that Lua programs
 * should be able to interact with: a {@link li.cil.oc.api.network.Component}.
 * <p/>
 * Note that for tile entities you implement yourself, you will not have to
 * provide a driver, as long as you implement the necessary interface:
 * {@link li.cil.oc.api.network.Environment}. For items that should be installed
 * in a computer, however, you will always have to provide a driver.
 * </dd>
 * <dt>The {@link FileSystem} API</dt>
 * <dd>
 * This API provides facilities that make it easier to create file systems that
 * can be interacted with from Lua programs via the file system driver that
 * comes with the mod.
 * </dd>
 * <dt>The {@link Network} API</dt>
 * <dd>
 * This API provides interfaces that allow interacting with the internal network
 * and creating nodes, components and power connectors for said network. If you
 * implement <tt>Environment</tt> in your tile entity or provide a
 * {@link li.cil.oc.api.network.ManagedEnvironment} via a driver you'll have to
 * create a node. This API provides factory methods for creating it.
 * </dd>
 * </dl>
 */
@cpw.mods.fml.common.API(
        owner = "OpenComputers",
        provides = "OpenComputersAPI",
        apiVersion = "1.0.0")
package li.cil.oc.api;