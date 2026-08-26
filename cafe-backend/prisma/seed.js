const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log("⏳ Bắt đầu làm mới dữ liệu hệ thống (Menu SAM CAFE)...");

  // VÔ HIỆU HÓA KHÓA NGOẠI TẠM THỜI (Hỗ trợ SQLite / MySQL)
  try { await prisma.$executeRawUnsafe(`PRAGMA foreign_keys = OFF;`); } catch (e) {}
  try { await prisma.$executeRawUnsafe(`SET foreign_key_checks = 0;`); } catch (e) {}

  // XÓA SẠCH TẤT CẢ CÁC BẢNG KHÔNG CÒN VƯỚNG RÀNG BUỘC
  console.log("🧹 Đang dọn dẹp sạch toàn bộ dữ liệu cũ...");
  try { await prisma.invoiceItem.deleteMany({}); } catch (e) {}
  try { await prisma.orderItem.deleteMany({}); } catch (e) {}
  try { await prisma.invoice.deleteMany({}); } catch (e) {}
  try { await prisma.order.deleteMany({}); } catch (e) {}
  await prisma.product.deleteMany({});
  await prisma.category.deleteMany({});
  await prisma.table.deleteMany({});

  // BẬT LẠI KIỂM TRA KHÓA NGOẠI
  try { await prisma.$executeRawUnsafe(`PRAGMA foreign_keys = ON;`); } catch (e) {}
  try { await prisma.$executeRawUnsafe(`SET foreign_key_checks = 1;`); } catch (e) {}

  // 1. TẠO LẠI BÀN
  const tables = [];
  for (let i = 1; i <= 18; i++) tables.push({ id: `S${i}`, name: `Bàn S${i}` });
  for (let i = 1; i <= 4; i++) tables.push({ id: `V${i}`, name: `Vỉa hè ${i}` });
  for (let i = 1; i <= 4; i++) tables.push({ id: `N${i}`, name: `Nhà ${i}` });

  await prisma.table.createMany({ data: tables, skipDuplicates: true });
  console.log("✅ Đã thiết lập xong sơ đồ 26 bàn");

  // 2. TẠO DANH MỤC SAM CAFE
  const catCoffee = await prisma.category.create({ data: { name: 'Cà Phê & Đá Xay' } });
  const catTea = await prisma.category.create({ data: { name: 'Trà & Lipton' } });
  const catJuice = await prisma.category.create({ data: { name: 'Sinh Tố & Sữa Chua' } });
  const catSoda = await prisma.category.create({ data: { name: 'Soda & Giải Khát' } });
  const catFood = await prisma.category.create({ data: { name: 'Điểm Tâm' } });
  console.log("✅ Đã thiết lập xong 5 Nhóm danh mục SAM CAFE");

  // 3. TẠO 51 MÓN ĂN
  const products = [
    { id: 'CF01', categoryId: catCoffee.id, name: 'Americano Nóng/Đá', price: 18000 },
    { id: 'CF02', categoryId: catCoffee.id, name: 'Cà Phê SAM Nóng/Đá', price: 18000 },
    { id: 'CF03', categoryId: catCoffee.id, name: 'Cà Phê Sữa Nóng/Đá', price: 20000 },
    { id: 'CF04', categoryId: catCoffee.id, name: 'Bạc Xỉu Nóng/Đá', price: 25000 },
    { id: 'CF05', categoryId: catCoffee.id, name: 'Cà Phê Muối', price: 28000 },
    { id: 'CF06', categoryId: catCoffee.id, name: 'Cacao Muối', price: 28000 },
    { id: 'CF07', categoryId: catCoffee.id, name: 'Cacao Sữa', price: 32000 },
    { id: 'CF08', categoryId: catCoffee.id, name: 'Cà Phê Trứng Nóng', price: 45000 },
    { id: 'DX01', categoryId: catCoffee.id, name: 'Cà Phê Đá Xay', price: 30000 },
    { id: 'DX02', categoryId: catCoffee.id, name: 'Cacao Đá Xay', price: 35000 },
    { id: 'DX03', categoryId: catCoffee.id, name: 'Matcha Đá Xay', price: 35000 },

    { id: 'TR01', categoryId: catTea.id, name: 'Trà Thanh Yên', price: 30000 },
    { id: 'TR02', categoryId: catTea.id, name: 'Trà Lài M.Ong Chanh Vàng', price: 30000 },
    { id: 'TR03', categoryId: catTea.id, name: 'Hồng Đài Cam Vàng', price: 30000 },
    { id: 'TR04', categoryId: catTea.id, name: 'Trà Đào', price: 30000 },
    { id: 'TR05', categoryId: catTea.id, name: 'Trà Dâu', price: 30000 },
    { id: 'TR06', categoryId: catTea.id, name: 'Trà Vải Nha Đam Hạt Chia', price: 30000 },
    { id: 'TR07', categoryId: catTea.id, name: 'Trà Thảo Mộc Nóng', price: 20000 },
    { id: 'TS01', categoryId: catTea.id, name: 'Trà Sữa Truyền Thống', price: 25000 },
    { id: 'LP01', categoryId: catTea.id, name: 'Lipton Chanh', price: 20000 },
    { id: 'LP02', categoryId: catTea.id, name: 'Lipton Cam Xí Muội', price: 30000 },
    { id: 'LP03', categoryId: catTea.id, name: 'Lipton Chanh Dây', price: 28000 },
    { id: 'LP04', categoryId: catTea.id, name: 'Lipton Sữa', price: 22000 },
    { id: 'LP05', categoryId: catTea.id, name: 'Lipton Mật Ong', price: 25000 },

    { id: 'ST01', categoryId: catJuice.id, name: 'Sinh Tố Việt Quất', price: 30000 },
    { id: 'ST02', categoryId: catJuice.id, name: 'Sinh Tố Mãng Cầu', price: 30000 },
    { id: 'ST03', categoryId: catJuice.id, name: 'Sinh Tố Bơ', price: 30000 },
    { id: 'ST04', categoryId: catJuice.id, name: 'Sinh Tố Bơ Cà Phê', price: 35000 },
    { id: 'ST05', categoryId: catJuice.id, name: 'Sinh Tố Dâu', price: 35000 },
    { id: 'EP01', categoryId: catJuice.id, name: 'Nước Ép Cam', price: 20000 },
    { id: 'EP02', categoryId: catJuice.id, name: 'Nước Ép Dưa Hấu', price: 25000 },
    { id: 'EP03', categoryId: catJuice.id, name: 'Nước Ép Chanh Dây', price: 25000 },
    { id: 'EP04', categoryId: catJuice.id, name: 'Nước Ép Ổi', price: 25000 },
    { id: 'SC01', categoryId: catJuice.id, name: 'Sữa Chua Nha Đam Hạt Chia', price: 28000 },
    { id: 'SC02', categoryId: catJuice.id, name: 'Sữa Chua Việt Quất', price: 28000 },
    { id: 'SC03', categoryId: catJuice.id, name: 'Sữa Chua Dâu', price: 28000 },
    { id: 'SC04', categoryId: catJuice.id, name: 'Sữa Chua Đào', price: 28000 },

    { id: 'SD01', categoryId: catSoda.id, name: 'Soda Dâu', price: 25000 },
    { id: 'SD02', categoryId: catSoda.id, name: 'Soda Việt Quất', price: 25000 },
    { id: 'SD03', categoryId: catSoda.id, name: 'Soda Chanh', price: 25000 },
    { id: 'SD04', categoryId: catSoda.id, name: 'Soda Đào', price: 25000 },
    { id: 'TU01', categoryId: catSoda.id, name: 'Sữa Tươi', price: 20000 },
    { id: 'TU02', categoryId: catSoda.id, name: 'Đá Chanh', price: 20000 },
    { id: 'TU03', categoryId: catSoda.id, name: 'Rau Má', price: 17000 },
    { id: 'TU04', categoryId: catSoda.id, name: 'Rau Má Sữa', price: 20000 },
    { id: 'TU05', categoryId: catSoda.id, name: 'Rau Má Dừa Tươi', price: 25000 },
    { id: 'TU06', categoryId: catSoda.id, name: 'Dừa Tươi', price: 20000 },
    { id: 'TU07', categoryId: catSoda.id, name: 'Chanh Muối', price: 20000 },
    { id: 'TU08', categoryId: catSoda.id, name: 'Bạc Hà Sữa', price: 25000 },
    { id: 'TU09', categoryId: catSoda.id, name: 'Sting', price: 20000 },

    { id: 'DT01', categoryId: catFood.id, name: 'Bò Né', price: 45000 },
    { id: 'DT02', categoryId: catFood.id, name: 'Ốp La', price: 20000 },
    { id: 'DT03', categoryId: catFood.id, name: 'Ốp La Cá Mòi', price: 28000 },
    { id: 'DT04', categoryId: catFood.id, name: 'Mì Xào Bò + Trứng', price: 40000 },
  ];

  await prisma.product.createMany({ data: products, skipDuplicates: true });
  console.log(`✅ Đã nạp thành công ${products.length} món SAM CAFE!`);
  console.log("🎉 XONG! Mọi vướng mắc đã được giải quyết triệt để.");
}

main()
  .catch((e) => {
    console.error("❌ Lỗi:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });