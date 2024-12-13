const Product = require('../models/product');
const AWS = require('aws-sdk');
const s3 = new AWS.S3();

exports.createProduct = async (req, res) => {
  try {
    const { name, description, price, category, stock } = req.body;
    let imageUrl = null;

    if (req.file) {
      const params = {
        Bucket: process.env.AWS_S3_BUCKET,
        Key: `products/${Date.now()}-${req.file.originalname}`,
        Body: req.file.buffer
      };

      const s3Response = await s3.upload(params).promise();
      imageUrl = s3Response.Location;
    }

    const product = await Product.create({
      name,
      description,
      price,
      category,
      stock,
      imageUrl
    });

    res.status(201).json(product);
  } catch (error) {
    res.status(500).json({ message: 'Error creating product', error: error.message });
  }
};

exports.getProducts = async (req, res) => {
  try {
    const { category, search, page = 1, limit = 10 } = req.query;
    const offset = (page - 1) * limit;
    
    let whereClause = { isActive: true };
    if (category) whereClause.category = category;
    if (search) {
      whereClause = {
        ...whereClause,
        [Op.or]: [
          { name: { [Op.iLike]: `%${search}%` } },
          { description: { [Op.iLike]: `%${search}%` } }
        ]
      };
    }

    const products = await Product.findAndCountAll({
      where: whereClause,
      limit: parseInt(limit),
      offset: parseInt(offset),
      order: [['createdAt', 'DESC']]
    });

    res.json({
      products: products.rows,
      totalPages: Math.ceil(products.count / limit),
      currentPage: parseInt(page)
    });
  } catch (error) {
    res.status(500).json({ message: 'Error fetching products', error: error.message });
  }
};

exports.getProduct = async (req, res) => {
  try {
    const product = await Product.findByPk(req.params.id);
    if (!product) {
      return res.status(404).json({ message: 'Product not found' });
    }
    res.json(product);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching product', error: error.message });
  }
};

exports.updateProduct = async (req, res) => {
  try {
    const product = await Product.findByPk(req.params.id);
    if (!product) {
      return res.status(404).json({ message: 'Product not found' });
    }

    const { name, description, price, category, stock } = req.body;
    let imageUrl = product.imageUrl;

    if (req.file) {
      // Delete old image if exists
      if (product.imageUrl) {
        const oldKey = product.imageUrl.split('/').pop();
        await s3.deleteObject({
          Bucket: process.env.AWS_S3_BUCKET,
          Key: `products/${oldKey}`
        }).promise();
      }

      // Upload new image
      const params = {
        Bucket: process.env.AWS_S3_BUCKET,
        Key: `products/${Date.now()}-${req.file.originalname}`,
        Body: req.file.buffer
      };

      const s3Response = await s3.upload(params).promise();
      imageUrl = s3Response.Location;
    }

    await product.update({
      name,
      description,
      price,
      category,
      stock,
      imageUrl
    });

    res.json(product);
  } catch (error) {
    res.status(500).json({ message: 'Error updating product', error: error.message });
  }
};

exports.deleteProduct = async (req, res) => {
  try {
    const product = await Product.findByPk(req.params.id);
    if (!product) {
      return res.status(404).json({ message: 'Product not found' });
    }

    // Soft delete
    await product.update({ isActive: false });
    res.json({ message: 'Product deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Error deleting product', error: error.message });
  }
};
