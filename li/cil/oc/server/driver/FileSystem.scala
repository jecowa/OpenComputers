package li.cil.oc.server.driver

import li.cil.oc
import li.cil.oc.api.driver.Slot
import li.cil.oc.common.item.{Disk, HardDiskDrive}
import li.cil.oc.{Config, Items}
import net.minecraft.item.ItemStack
import net.minecraft.nbt.NBTTagCompound

object FileSystem extends Item {
  override def worksWith(item: ItemStack) = WorksWith(Items.hdd1, Items.hdd2, Items.hdd3, Items.disk)(item)

  override def createEnvironment(item: ItemStack) = Items.multi.subItem(item) match {
    case Some(hdd: HardDiskDrive) => createEnvironment(item, hdd.megaBytes * 1024 * 1024)
    case Some(disk: Disk) => createEnvironment(item, 512 * 1024)
    case _ => null
  }

  override def slot(item: ItemStack) = Items.multi.subItem(item) match {
    case Some(hdd: HardDiskDrive) => Slot.HardDiskDrive
    case Some(disk: Disk) => Slot.Disk
    case _ => throw new IllegalArgumentException()
  }

  private def createEnvironment(item: ItemStack, capacity: Int) = {
    // We have a bit of a chicken-egg problem here, because we want to use the
    // node's address as the folder name... so we generate the address here,
    // if necessary. No one will know, right? Right!?
    val address = addressFromTag(nbt(item))
    Option(oc.api.FileSystem.fromSaveDirectory(address, capacity, Config.filesBuffered)).
      flatMap(fs => Option(oc.api.FileSystem.asManagedEnvironment(fs))) match {
      case Some(environment) =>
        environment.node.asInstanceOf[oc.server.network.Node].address = address
        environment
      case _ => null
    }
  }

  private def addressFromTag(tag: NBTTagCompound) =
    if (tag.hasKey("oc.node.address")) tag.getString("oc.node.address")
    else java.util.UUID.randomUUID().toString
}