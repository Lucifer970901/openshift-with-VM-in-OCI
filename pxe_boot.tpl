#!ipxe
kernel http://${pxe_server_ip}/images/pxeboot/vmlinuz initrd=main random.trust_cpu=on  ignition.firstboot ignition.platform.id=metal coreos.inst.ignition_url=http://${pxe_server_ip}/config.ign coreos.live.rootfs_url=http://${pxe_server_ip}/images/pxeboot/rootfs.img  ignition.config.url=http://${pxe_server_ip}/config.ign
initrd --name main http://${pxe_server_ip}/images/pxeboot/initrd.img 
initrd http://${pxe_server_ip}/images/ignition.img
boot
