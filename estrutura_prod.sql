
/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
DROP TABLE IF EXISTS `bairro`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `bairro` (
  `bairro_id` bigint NOT NULL AUTO_INCREMENT,
  `cidade_id` bigint NOT NULL,
  `nmbairro` varchar(120) NOT NULL,
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`bairro_id`),
  UNIQUE KEY `uk_bairro_cidade_nome` (`cidade_id`,`nmbairro`),
  CONSTRAINT `fk_bairro_cidade` FOREIGN KEY (`cidade_id`) REFERENCES `cidade` (`cidade_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `carrinho`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `carrinho` (
  `carrinho_id` bigint NOT NULL AUTO_INCREMENT,
  `organizacao_id` bigint NOT NULL,
  `loja_id` bigint NOT NULL,
  `cliente_id` bigint NOT NULL,
  `sitcarrinho` enum('ABERTO','FECHADO') NOT NULL DEFAULT 'ABERTO',
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `idpixmercadopago` varchar(80) DEFAULT NULL,
  `vrpixmercadopago` decimal(12,2) DEFAULT NULL,
  PRIMARY KEY (`carrinho_id`),
  KEY `fk_carrinho_cliente` (`cliente_id`),
  KEY `idx_carrinho_aberto_cliente_loja` (`organizacao_id`,`loja_id`,`cliente_id`,`sitcarrinho`),
  CONSTRAINT `fk_carrinho_cliente` FOREIGN KEY (`cliente_id`) REFERENCES `cliente` (`cliente_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_carrinho_loja_org` FOREIGN KEY (`organizacao_id`, `loja_id`) REFERENCES `loja` (`organizacao_id`, `loja_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=202 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `cashback_config`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cashback_config` (
  `cashback_config_id` bigint NOT NULL AUTO_INCREMENT,
  `organizacao_id` bigint NOT NULL,
  `loja_id` bigint NOT NULL,
  `sitcashback` varchar(10) NOT NULL DEFAULT 'ATIVO',
  `pccashback` decimal(10,2) NOT NULL DEFAULT '0.00',
  `vrmincompra` decimal(10,2) NOT NULL DEFAULT '0.00',
  `vrmaxcashback` decimal(10,2) DEFAULT NULL,
  `nrdiapliberacao` int NOT NULL DEFAULT '0',
  `nrdiavalidade` int NOT NULL DEFAULT '90',
  `permiteusoparcial` char(1) NOT NULL DEFAULT 'S',
  `pcmaxusocompra` decimal(10,2) DEFAULT NULL,
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`cashback_config_id`),
  UNIQUE KEY `uk_cashback_config_loja` (`loja_id`),
  KEY `idx_cashback_config_organizacao` (`organizacao_id`),
  KEY `idx_cashback_config_situacao` (`sitcashback`),
  KEY `idx_cashback_config_org_loja` (`organizacao_id`,`loja_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `cashback_movimento`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cashback_movimento` (
  `cashback_movimento_id` bigint NOT NULL AUTO_INCREMENT,
  `cliente_id` bigint NOT NULL,
  `organizacao_id` bigint NOT NULL,
  `loja_id` bigint NOT NULL,
  `venda_origem_id` bigint DEFAULT NULL,
  `venda_uso_id` bigint DEFAULT NULL,
  `tipomovimento` varchar(15) NOT NULL,
  `sitcashback` varchar(15) NOT NULL,
  `pcaplicado` decimal(10,2) NOT NULL DEFAULT '0.00',
  `vrbase` decimal(10,2) NOT NULL DEFAULT '0.00',
  `vrcashback` decimal(10,2) NOT NULL DEFAULT '0.00',
  `descricao` varchar(255) DEFAULT NULL,
  `observacao` varchar(500) DEFAULT NULL,
  `dtmovimento` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtliberacao` datetime DEFAULT NULL,
  `dtvalidade` datetime DEFAULT NULL,
  `dtutilizacao` datetime DEFAULT NULL,
  PRIMARY KEY (`cashback_movimento_id`),
  KEY `idx_cashback_cliente_loja` (`cliente_id`,`loja_id`),
  KEY `idx_cashback_status` (`sitcashback`),
  KEY `idx_cashback_venda_origem` (`venda_origem_id`),
  KEY `idx_cashback_venda_uso` (`venda_uso_id`),
  KEY `idx_cashback_movimento_data` (`dtmovimento`),
  KEY `idx_cashback_movimento_org_loja` (`organizacao_id`,`loja_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `cashback_saldo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cashback_saldo` (
  `cashback_saldo_id` bigint NOT NULL AUTO_INCREMENT,
  `cliente_id` bigint NOT NULL,
  `organizacao_id` bigint NOT NULL,
  `loja_id` bigint NOT NULL,
  `vrdisponivel` decimal(10,2) NOT NULL DEFAULT '0.00',
  `vrpendente` decimal(10,2) NOT NULL DEFAULT '0.00',
  `dtultatu` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`cashback_saldo_id`),
  UNIQUE KEY `uk_cashback_saldo_cliente_loja` (`cliente_id`,`loja_id`),
  KEY `idx_cashback_saldo_cliente` (`cliente_id`),
  KEY `idx_cashback_saldo_org_loja` (`organizacao_id`,`loja_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `categoria`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `categoria` (
  `categoria_id` bigint NOT NULL AUTO_INCREMENT,
  `organizacao_id` bigint NOT NULL,
  `loja_id` bigint NOT NULL,
  `nmcategoria` varchar(120) NOT NULL,
  `sitcategoria` enum('ATIVA','INATIVA') NOT NULL DEFAULT 'ATIVA',
  `idordcategoria` bigint NOT NULL DEFAULT '1',
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`categoria_id`),
  UNIQUE KEY `uk_categoria_nome` (`loja_id`,`nmcategoria`),
  UNIQUE KEY `uk_categoria_composta` (`organizacao_id`,`loja_id`,`categoria_id`),
  KEY `idx_categoria_loja` (`loja_id`),
  CONSTRAINT `fk_categoria_loja` FOREIGN KEY (`organizacao_id`, `loja_id`) REFERENCES `loja` (`organizacao_id`, `loja_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `checkout_asaas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `checkout_asaas` (
  `checkout_asaas_id` bigint NOT NULL AUTO_INCREMENT,
  `carrinho_id` bigint NOT NULL,
  `cliente_id` bigint NOT NULL,
  `loja_id` bigint NOT NULL,
  `checkout_id` varchar(100) NOT NULL,
  `payment_id` varchar(100) DEFAULT NULL,
  `external_reference` varchar(100) DEFAULT NULL,
  `status` varchar(30) DEFAULT 'ACTIVE',
  `dtcriacao` datetime DEFAULT CURRENT_TIMESTAMP,
  `checkout_url` varchar(500) DEFAULT NULL,
  `valor` decimal(10,2) DEFAULT NULL,
  PRIMARY KEY (`checkout_asaas_id`),
  UNIQUE KEY `uk_checkout_id` (`checkout_id`)
) ENGINE=InnoDB AUTO_INCREMENT=78 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `cidade`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cidade` (
  `cidade_id` bigint NOT NULL AUTO_INCREMENT,
  `pais_id` bigint NOT NULL,
  `estado_id` bigint NOT NULL,
  `cdibgecid` bigint DEFAULT NULL,
  `nmcidade` varchar(120) NOT NULL,
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`cidade_id`),
  UNIQUE KEY `uk_cidade_estado_nome` (`estado_id`,`nmcidade`),
  UNIQUE KEY `uk_cidade_pais_estado_id` (`pais_id`,`estado_id`,`cidade_id`),
  CONSTRAINT `fk_cidade_estado_pais` FOREIGN KEY (`pais_id`, `estado_id`) REFERENCES `estado` (`pais_id`, `estado_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `cliente`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cliente` (
  `cliente_id` bigint NOT NULL AUTO_INCREMENT,
  `nmcliente` varchar(120) NOT NULL,
  `emailcliente` varchar(160) NOT NULL,
  `senhahashcli` varchar(255) NOT NULL,
  `sitcliente` varchar(15) NOT NULL DEFAULT 'ATIVO',
  `emailconf` char(1) NOT NULL DEFAULT 'N',
  `nrtelcliente` varchar(15) DEFAULT NULL,
  `nrcpfcliente` varchar(15) DEFAULT NULL,
  `endcliente` varchar(150) DEFAULT NULL,
  `nrendcliente` varchar(20) DEFAULT NULL,
  `complcliente` varchar(80) DEFAULT NULL,
  `bairrocliente` varchar(80) DEFAULT NULL,
  `cepcliente` varchar(10) DEFAULT NULL,
  `cidadecliente` varchar(100) DEFAULT NULL,
  `ufcliente` char(2) DEFAULT NULL,
  `idcidadeibge` int DEFAULT NULL,
  `dtnascimento` date DEFAULT NULL,
  `pais_id` bigint DEFAULT NULL,
  `estado_id` bigint DEFAULT NULL,
  `cidade_id` bigint DEFAULT NULL,
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `idclienteasaas` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`cliente_id`),
  UNIQUE KEY `uk_cliente_email` (`emailcliente`),
  UNIQUE KEY `uq_cliente_cpf` (`nrcpfcliente`),
  KEY `idx_cliente_email` (`emailcliente`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `clisenha`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `clisenha` (
  `clisenha_id` bigint NOT NULL AUTO_INCREMENT,
  `cliente_id` bigint NOT NULL,
  `codigo` varchar(10) NOT NULL,
  `expiracao` datetime NOT NULL,
  `usado` char(1) NOT NULL DEFAULT 'N',
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`clisenha_id`),
  KEY `fk_clisenha` (`cliente_id`),
  CONSTRAINT `fk_clisenha` FOREIGN KEY (`cliente_id`) REFERENCES `cliente` (`cliente_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=22 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `estado`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `estado` (
  `estado_id` bigint NOT NULL AUTO_INCREMENT,
  `pais_id` bigint NOT NULL,
  `cdibgeest` bigint DEFAULT NULL,
  `sgestado` varchar(5) NOT NULL,
  `nmestado` varchar(120) NOT NULL,
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`estado_id`),
  UNIQUE KEY `uk_estado_pais_sigla` (`pais_id`,`sgestado`),
  UNIQUE KEY `uk_estado_pais_estadoid` (`pais_id`,`estado_id`),
  UNIQUE KEY `uk_estado_ibge` (`cdibgeest`),
  CONSTRAINT `fk_estado_pais` FOREIGN KEY (`pais_id`) REFERENCES `pais` (`pais_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `evento`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `evento` (
  `evento_id` bigint NOT NULL AUTO_INCREMENT,
  `organizacao_id` bigint NOT NULL,
  `loja_id` bigint NOT NULL,
  `nmtituloevento` varchar(120) NOT NULL,
  `dsdescevento` text,
  `dtinicioevento` datetime NOT NULL,
  `dtfimevento` datetime DEFAULT NULL,
  `nmlocalevento` varchar(120) DEFAULT NULL,
  `dsendlocevento` varchar(200) DEFAULT NULL,
  `urlbannerevento` varchar(255) DEFAULT NULL,
  `statusevento` enum('RASCUNHO','ATIVO','ENCERRADO','CANCELADO') NOT NULL DEFAULT 'RASCUNHO',
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`evento_id`),
  KEY `idx_evento_loja_status_dt` (`organizacao_id`,`loja_id`,`statusevento`,`dtinicioevento`),
  KEY `idx_evento_titulo` (`nmtituloevento`),
  CONSTRAINT `fk_evento_loja` FOREIGN KEY (`organizacao_id`, `loja_id`) REFERENCES `loja` (`organizacao_id`, `loja_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `eventolote`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eventolote` (
  `lote_id` bigint NOT NULL AUTO_INCREMENT,
  `organizacao_id` bigint NOT NULL,
  `loja_id` bigint NOT NULL,
  `evento_id` bigint NOT NULL,
  `nmlote` varchar(80) NOT NULL,
  `vrprecolote` decimal(10,2) NOT NULL DEFAULT '0.00',
  `qttotallote` int NOT NULL DEFAULT '0',
  `qtvendidalote` int NOT NULL DEFAULT '0',
  `dtiniciovenda` datetime DEFAULT NULL,
  `dtfimvenda` datetime DEFAULT NULL,
  `statuslote` enum('ATIVO','ESGOTADO','ENCERRADO','INATIVO') NOT NULL DEFAULT 'ATIVO',
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`lote_id`),
  KEY `idx_lote_evento_status` (`evento_id`,`statuslote`),
  KEY `idx_lote_loja_evento` (`organizacao_id`,`loja_id`,`evento_id`),
  CONSTRAINT `fk_lote_evento` FOREIGN KEY (`evento_id`) REFERENCES `evento` (`evento_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_lote_loja` FOREIGN KEY (`organizacao_id`, `loja_id`) REFERENCES `loja` (`organizacao_id`, `loja_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `itcarrinho`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `itcarrinho` (
  `itcarrinho_id` bigint NOT NULL AUTO_INCREMENT,
  `carrinho_id` bigint NOT NULL,
  `produto_id` bigint NOT NULL,
  `lote_id` bigint DEFAULT NULL,
  `qtitcarrinho` int NOT NULL DEFAULT '1',
  `dsobsitcar` varchar(255) DEFAULT NULL,
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `nmparticipante` varchar(150) DEFAULT NULL,
  `cpfparticipante` varchar(14) DEFAULT NULL,
  PRIMARY KEY (`itcarrinho_id`),
  KEY `fk_itcarrinho_produto` (`produto_id`),
  KEY `idx_itcarrinho_carrinho` (`carrinho_id`),
  KEY `idx_itcarrinho_carrinho_produto` (`carrinho_id`,`produto_id`),
  KEY `idx_itcarrinho_lote` (`lote_id`),
  KEY `idx_itcarrinho_carrinho_dt` (`carrinho_id`,`dtcriacao`,`itcarrinho_id`),
  CONSTRAINT `fk_itcarrinho_carrinho` FOREIGN KEY (`carrinho_id`) REFERENCES `carrinho` (`carrinho_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_itcarrinho_lote` FOREIGN KEY (`lote_id`) REFERENCES `eventolote` (`lote_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_itcarrinho_produto` FOREIGN KEY (`produto_id`) REFERENCES `produto` (`produto_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_itcarrinho_qt` CHECK ((`qtitcarrinho` = 1))
) ENGINE=InnoDB AUTO_INCREMENT=377 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `itvenda`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `itvenda` (
  `itvenda_id` bigint NOT NULL AUTO_INCREMENT,
  `venda_id` bigint NOT NULL,
  `produto_id` bigint NOT NULL,
  `lote_id` bigint DEFAULT NULL,
  `qtitvenda` int NOT NULL DEFAULT '1',
  `vrunititvenda` decimal(10,2) NOT NULL,
  `identregaitvenda` enum('SIM','NAO') NOT NULL DEFAULT 'NAO',
  `dtentregaitvenda` datetime DEFAULT NULL,
  `dtexpiraitvenda` date DEFAULT NULL,
  `userentregaitvenda` bigint DEFAULT NULL,
  `nmuserentregaitvenda` varchar(100) DEFAULT NULL,
  `dsobsitvenda` varchar(255) DEFAULT NULL,
  `qrtokenitvenda` varchar(120) NOT NULL,
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `nmparticipante` varchar(150) DEFAULT NULL,
  `cpfparticipante` varchar(14) DEFAULT NULL,
  `pctaxaitvenda` decimal(10,2) DEFAULT NULL,
  `vrtaxaitvenda` decimal(10,2) DEFAULT NULL,
  PRIMARY KEY (`itvenda_id`),
  UNIQUE KEY `uq_itvenda_qrtoken` (`qrtokenitvenda`),
  KEY `fk_itvenda_produto` (`produto_id`),
  KEY `fk_itvenda_user_entrega` (`userentregaitvenda`),
  KEY `idx_itvenda_venda` (`venda_id`),
  KEY `idx_itvenda_lote` (`lote_id`),
  KEY `idx_itvenda_entrega` (`identregaitvenda`,`dtentregaitvenda`),
  CONSTRAINT `fk_itvenda_lote` FOREIGN KEY (`lote_id`) REFERENCES `eventolote` (`lote_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_itvenda_produto` FOREIGN KEY (`produto_id`) REFERENCES `produto` (`produto_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_itvenda_user_entrega` FOREIGN KEY (`userentregaitvenda`) REFERENCES `usuario` (`usuario_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_itvenda_venda` FOREIGN KEY (`venda_id`) REFERENCES `venda` (`venda_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_itvenda_qt` CHECK ((`qtitvenda` = 1))
) ENGINE=InnoDB AUTO_INCREMENT=540 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `lead_parceiro`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `lead_parceiro` (
  `lead_parceiro_id` bigint NOT NULL AUTO_INCREMENT,
  `nome_responsavel` varchar(120) NOT NULL,
  `nome_estabelecimento` varchar(160) NOT NULL,
  `tipo` varchar(30) NOT NULL,
  `telefone` varchar(30) NOT NULL,
  `email` varchar(160) NOT NULL,
  `cidade` varchar(120) NOT NULL,
  `mensagem` text,
  `status` enum('NOVO','CONTATADO','NEGOCIANDO','CONVERTIDO','PERDIDO') NOT NULL DEFAULT 'NOVO',
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`lead_parceiro_id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `leadacesso`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `leadacesso` (
  `leadacesso_id` bigint NOT NULL AUTO_INCREMENT,
  `leadparceiro_id` bigint NOT NULL,
  `tokenhash` char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `dtvalidade` datetime NOT NULL,
  `dtultimoacesso` datetime DEFAULT NULL,
  `revogado` char(1) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'N',
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`leadacesso_id`),
  UNIQUE KEY `uk_leadacesso_tokenhash` (`tokenhash`),
  KEY `fk_leadacesso_lead` (`leadparceiro_id`),
  CONSTRAINT `fk_leadacesso_lead` FOREIGN KEY (`leadparceiro_id`) REFERENCES `leadparceiro` (`leadparceiro_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `chk_leadacesso_revogado` CHECK ((`revogado` in (_utf8mb4'S',_utf8mb4'N')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `leadagendamento`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `leadagendamento` (
  `leadagendamento_id` bigint NOT NULL AUTO_INCREMENT,
  `leadparceiro_id` bigint NOT NULL,
  `tipo` enum('DEMONSTRACAO','LIGACAO','REUNIAO_ONLINE','VISITA') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `dtagendamento` datetime NOT NULL,
  `observacao` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('PENDENTE','CONFIRMADO','RECUSADO','REALIZADO','CANCELADO') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDENTE',
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`leadagendamento_id`),
  KEY `idx_leadagendamento_lead_data` (`leadparceiro_id`,`dtagendamento`),
  CONSTRAINT `fk_leadagendamento_lead` FOREIGN KEY (`leadparceiro_id`) REFERENCES `leadparceiro` (`leadparceiro_id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `leadmaterial`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `leadmaterial` (
  `leadmaterial_id` bigint NOT NULL AUTO_INCREMENT,
  `leadparceiro_id` bigint NOT NULL,
  `titulo` varchar(160) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `descricao` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tipo` enum('APRESENTACAO','PROPOSTA','CONTRATO','VIDEO','OUTRO') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `urlarquivo` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`leadmaterial_id`),
  KEY `idx_leadmaterial_lead` (`leadparceiro_id`,`dtcriacao`),
  CONSTRAINT `fk_leadmaterial_lead` FOREIGN KEY (`leadparceiro_id`) REFERENCES `leadparceiro` (`leadparceiro_id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `leadmensagem`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `leadmensagem` (
  `leadmensagem_id` bigint NOT NULL AUTO_INCREMENT,
  `leadparceiro_id` bigint NOT NULL,
  `origem` enum('CLUBBAR','LEAD') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `mensagem` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `lida` char(1) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'N',
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`leadmensagem_id`),
  KEY `idx_leadmensagem_lead_data` (`leadparceiro_id`,`dtcriacao`),
  CONSTRAINT `fk_leadmensagem_lead` FOREIGN KEY (`leadparceiro_id`) REFERENCES `leadparceiro` (`leadparceiro_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `chk_leadmensagem_lida` CHECK ((`lida` in (_utf8mb4'S',_utf8mb4'N')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `leadparceiro`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `leadparceiro` (
  `leadparceiro_id` bigint NOT NULL AUTO_INCREMENT,
  `nmresponsavel` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `nmestabelecimento` varchar(160) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `tipo` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `tipovenda` enum('PRODUTOS','INGRESSOS','AMBOS') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'AMBOS',
  `telefone` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(160) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `estado_id` bigint NOT NULL,
  `cidade_id` bigint NOT NULL,
  `mensagem` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `status` enum('NOVO','CONTATADO','NEGOCIANDO','CONVERTIDO','PERDIDO') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'NOVO',
  `decisao` enum('PENDENTE','ACEITOU','RECUSOU') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDENTE',
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`leadparceiro_id`),
  KEY `idx_leadparceiro_status` (`status`),
  KEY `idx_leadparceiro_estado` (`estado_id`),
  KEY `idx_leadparceiro_cidade` (`cidade_id`),
  KEY `idx_leadparceiro_email` (`email`),
  KEY `idx_leadparceiro_dtcriacao` (`dtcriacao`),
  CONSTRAINT `fk_leadparceiro_cidade` FOREIGN KEY (`cidade_id`) REFERENCES `cidade` (`cidade_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_leadparceiro_estado` FOREIGN KEY (`estado_id`) REFERENCES `estado` (`estado_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `chk_leadparceiro_tipo` CHECK ((`tipo` in (_utf8mb4'BAR',_utf8mb4'CASA_NOTURNA',_utf8mb4'PRODUTOR_EVENTOS')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `loja`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `loja` (
  `loja_id` bigint NOT NULL AUTO_INCREMENT,
  `organizacao_id` bigint NOT NULL,
  `nmloja` varchar(120) NOT NULL,
  `endloja` varchar(255) DEFAULT NULL,
  `dsrefeloja` varchar(255) DEFAULT NULL,
  `dsinstaloja` varchar(255) DEFAULT NULL,
  `dsbairroloja` varchar(120) DEFAULT NULL,
  `sitloja` varchar(15) NOT NULL DEFAULT 'ATIVA',
  `aberto24x7` char(1) NOT NULL DEFAULT 'N',
  `nrtelloja` varchar(25) DEFAULT NULL,
  `nrdiavalidade` bigint NOT NULL DEFAULT '90',
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `cidade_id` bigint DEFAULT NULL,
  `urllogoloja` varchar(255) DEFAULT NULL,
  `urlfachadaloja` varchar(255) DEFAULT NULL,
  `vrtaxaprod` decimal(10,2) NOT NULL DEFAULT '3.00',
  `vrtaxaing` decimal(10,2) NOT NULL DEFAULT '10.00',
  `dsestiloloja` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`loja_id`),
  UNIQUE KEY `uk_loja_org_id` (`organizacao_id`,`loja_id`),
  KEY `fk_loja_cidade` (`cidade_id`),
  KEY `idx_loja_org` (`organizacao_id`),
  KEY `idx_loja` (`loja_id`),
  CONSTRAINT `fk_loja_cidade` FOREIGN KEY (`cidade_id`) REFERENCES `cidade` (`cidade_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_loja_org` FOREIGN KEY (`organizacao_id`) REFERENCES `organizacao` (`organizacao_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `chk_aberto24x7` CHECK ((`aberto24x7` in (_utf8mb4'S',_utf8mb4'N')))
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `lojahorario`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `lojahorario` (
  `lojahorario_id` bigint NOT NULL AUTO_INCREMENT,
  `loja_id` bigint NOT NULL,
  `diasemana` tinyint unsigned NOT NULL,
  `fechado` tinyint(1) NOT NULL DEFAULT '0',
  `horaabertura` time DEFAULT NULL,
  `horafechamento` time DEFAULT NULL,
  `fechadiaseguinte` tinyint(1) NOT NULL DEFAULT '0',
  `dtcriacao` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtalteracao` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`lojahorario_id`),
  UNIQUE KEY `uq_lojahorario_dia` (`loja_id`,`diasemana`),
  KEY `ix_lojahorario_loja` (`loja_id`),
  CONSTRAINT `fk_lojahorario_loja` FOREIGN KEY (`loja_id`) REFERENCES `loja` (`loja_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `ck_lojahorario_campos` CHECK ((((`fechado` = true) and (`horaabertura` is null) and (`horafechamento` is null) and (`fechadiaseguinte` = false)) or ((`fechado` = false) and (`horaabertura` is not null) and (`horafechamento` is not null) and (`horaabertura` <> `horafechamento`)))),
  CONSTRAINT `ck_lojahorario_dia` CHECK ((`diasemana` between 1 and 7))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `organizacao`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `organizacao` (
  `organizacao_id` bigint NOT NULL AUTO_INCREMENT,
  `nmorganizacao` varchar(120) NOT NULL,
  `rzsocialorganizacao` varchar(160) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cnpjorganizacao` varchar(18) DEFAULT NULL,
  `emailorganizacao` varchar(255) DEFAULT NULL,
  `telorganizacao` varchar(25) DEFAULT NULL,
  `ceporganizacao` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `endorganizacao` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `nrendorganizacao` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `complorganizacao` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cidade_id` bigint DEFAULT NULL,
  `nmbairro` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `leadparceiro_id` bigint DEFAULT NULL,
  `sitorganizacao` varchar(15) NOT NULL DEFAULT 'ATIVA',
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`organizacao_id`),
  UNIQUE KEY `uq_organizacao_leadparceiro` (`leadparceiro_id`),
  KEY `idx_organizacao_nome` (`nmorganizacao`),
  KEY `idx_organizacao_situacao` (`sitorganizacao`),
  KEY `idx_organizacao_cidade` (`cidade_id`),
  CONSTRAINT `fk_organizacao_cidade` FOREIGN KEY (`cidade_id`) REFERENCES `cidade` (`cidade_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_organizacao_leadparceiro` FOREIGN KEY (`leadparceiro_id`) REFERENCES `leadparceiro` (`leadparceiro_id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=1000000 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `pagvenda`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pagvenda` (
  `pagvenda_id` bigint NOT NULL AUTO_INCREMENT,
  `venda_id` bigint NOT NULL,
  `dsmetodopag` varchar(40) NOT NULL,
  `vrpagvenda` decimal(10,2) NOT NULL,
  `sitpagvenda` enum('PENDENTE','PAGO','CANCELADO') NOT NULL DEFAULT 'PENDENTE',
  `idtransacaopagvenda` varchar(120) DEFAULT NULL,
  `dtconftranspagvenda` datetime DEFAULT NULL,
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `provedor` varchar(40) NOT NULL DEFAULT 'MERCADOPAGO',
  `reference_id` varchar(80) DEFAULT NULL,
  `checkout_id` varchar(120) DEFAULT NULL,
  `pay_url` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`pagvenda_id`),
  KEY `idx_pagvenda` (`venda_id`),
  KEY `idx_sitpagvenda` (`sitpagvenda`,`dtcriacao`),
  KEY `idx_pagvenda_reference` (`reference_id`),
  CONSTRAINT `fk_pagamento_venda` FOREIGN KEY (`venda_id`) REFERENCES `venda` (`venda_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=209 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `pais`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pais` (
  `pais_id` bigint NOT NULL AUTO_INCREMENT,
  `cdpais` bigint NOT NULL,
  `nmpais` varchar(120) NOT NULL,
  `sgpais` varchar(5) DEFAULT NULL,
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`pais_id`),
  UNIQUE KEY `uk_pais_cdpais` (`cdpais`),
  UNIQUE KEY `uk_pais_nome` (`nmpais`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `produto`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `produto` (
  `produto_id` bigint NOT NULL AUTO_INCREMENT,
  `organizacao_id` bigint NOT NULL,
  `loja_id` bigint NOT NULL,
  `categoria_id` bigint DEFAULT NULL,
  `nmproduto` varchar(100) NOT NULL,
  `dsproduto` varchar(255) DEFAULT NULL,
  `idtipoproduto` enum('I','P') NOT NULL DEFAULT 'P',
  `vrprecoprod` decimal(10,2) NOT NULL,
  `sitproduto` enum('ATIVO','INATIVO') NOT NULL DEFAULT 'ATIVO',
  `skuproduto` varchar(100) DEFAULT NULL,
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `lote_id` bigint DEFAULT NULL,
  `urlfotoproduto` varchar(255) DEFAULT NULL,
  `tipodesconto` enum('NENHUM','PERCENTUAL','VALOR') NOT NULL DEFAULT 'NENHUM',
  `vrdesconto` decimal(10,2) NOT NULL DEFAULT '0.00',
  `dtinidesconto` datetime DEFAULT NULL,
  `dtfimdesconto` datetime DEFAULT NULL,
  PRIMARY KEY (`produto_id`),
  UNIQUE KEY `uq_produto_lote` (`organizacao_id`,`loja_id`,`lote_id`),
  KEY `fk_produto_categoria_composta` (`organizacao_id`,`loja_id`,`categoria_id`),
  KEY `idx_produto_org_loja_sit` (`organizacao_id`,`loja_id`,`sitproduto`),
  KEY `idx_produto_org_loja_sit_nome` (`organizacao_id`,`loja_id`,`sitproduto`,`nmproduto`),
  KEY `idx_produto_categoria` (`categoria_id`),
  KEY `fk_produto_eventolote` (`lote_id`),
  CONSTRAINT `fk_produto_categoria` FOREIGN KEY (`categoria_id`) REFERENCES `categoria` (`categoria_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_produto_categoria_composta` FOREIGN KEY (`organizacao_id`, `loja_id`, `categoria_id`) REFERENCES `categoria` (`organizacao_id`, `loja_id`, `categoria_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_produto_eventolote` FOREIGN KEY (`lote_id`) REFERENCES `eventolote` (`lote_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_produto_loja` FOREIGN KEY (`organizacao_id`, `loja_id`) REFERENCES `loja` (`organizacao_id`, `loja_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=41 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `usuario`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `usuario` (
  `usuario_id` bigint NOT NULL AUTO_INCREMENT,
  `organizacao_id` bigint NOT NULL,
  `loja_id` bigint DEFAULT NULL,
  `nmusuario` varchar(200) NOT NULL,
  `emailuser` varchar(200) NOT NULL,
  `senhahashuser` varchar(255) NOT NULL,
  `situsuario` varchar(15) NOT NULL DEFAULT 'ATIVO',
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `dscargo` enum('SUPERADMIN','ADMIN','GERENTE','CAIXA','BARMAN','GARCOM','PORTEIRO') NOT NULL DEFAULT 'BARMAN',
  PRIMARY KEY (`usuario_id`),
  UNIQUE KEY `uk_usuario_email` (`emailuser`),
  KEY `fk_usuario_org` (`organizacao_id`),
  KEY `idx_usuario_email` (`emailuser`),
  KEY `idx_usuario_loja` (`loja_id`),
  CONSTRAINT `fk_usuario_loja` FOREIGN KEY (`loja_id`) REFERENCES `loja` (`loja_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_usuario_org` FOREIGN KEY (`organizacao_id`) REFERENCES `organizacao` (`organizacao_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `venda`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `venda` (
  `venda_id` bigint NOT NULL AUTO_INCREMENT,
  `organizacao_id` bigint NOT NULL,
  `loja_id` bigint NOT NULL,
  `cliente_id` bigint NOT NULL,
  `carrinho_id` bigint NOT NULL,
  `dsplataforma` enum('ANDROID','TOTEM','IOS','WEB','OUTROS') NOT NULL DEFAULT 'OUTROS',
  `sitvenda` enum('PENDENTE','PAGA','CANCELADA') NOT NULL DEFAULT 'PENDENTE',
  `totalvenda` decimal(10,2) NOT NULL DEFAULT '0.00',
  `dtcriacao` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dtultatu` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`venda_id`),
  KEY `fk_venda_loja` (`loja_id`),
  KEY `fk_venda_carrinho` (`carrinho_id`),
  KEY `idx_venda_loja_cliente_data` (`organizacao_id`,`loja_id`,`cliente_id`,`dtcriacao`),
  KEY `idx_venda_cliente_data` (`cliente_id`,`dtcriacao`),
  CONSTRAINT `fk_venda_carrinho` FOREIGN KEY (`carrinho_id`) REFERENCES `carrinho` (`carrinho_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_venda_cliente` FOREIGN KEY (`cliente_id`) REFERENCES `cliente` (`cliente_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_venda_loja` FOREIGN KEY (`loja_id`) REFERENCES `loja` (`loja_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_venda_org` FOREIGN KEY (`organizacao_id`) REFERENCES `organizacao` (`organizacao_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=214 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

